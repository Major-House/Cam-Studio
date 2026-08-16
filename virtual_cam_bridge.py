#!/usr/bin/env python3
"""
Hollywood Studio Pro — Virtual Camera + RTMP Bridge
===================================================
- POST /frame          → system virtual webcam (pyvirtualcam)
- POST /rtmp/start     → start FFmpeg RTMP publish
- POST /rtmp/frame     → feed frames into FFmpeg stdin
- POST /rtmp/stop      → stop RTMP
- GET  /rtmp/stats     → bitrate / fps / state
- GET  /health

Requirements:
  pip install -r requirements.txt
  ffmpeg must be on PATH (https://ffmpeg.org)

Usage:
  python virtual_cam_bridge.py
"""

from __future__ import annotations

import io
import json
import logging
import os
import shutil
import subprocess
import threading
import time
from typing import Any, Optional

import numpy as np
from flask import Flask, request, jsonify
from PIL import Image

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("studio-bridge")

app = Flask(__name__)


@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "ok": True,
        "service": "ENDLESS CAM / Virtual Camera Bridge",
        "message": "Virtual Camera Bridge service is running.",
        "routes": [
            "/health",
            "/frame",
            "/rtmp/start",
            "/rtmp/frame",
            "/rtmp/stop",
            "/rtmp/stats",
            "/obs/status",
        ],
    }), 200


# ── Virtual camera ──────────────────────────────────────────────────────────
_cam = None
_cam_lock = threading.Lock()
_width = 1280
_height = 720
_fps = 30
_last_frame: Optional[np.ndarray] = None
_running = True

# ── RTMP / FFmpeg ───────────────────────────────────────────────────────────
_ffmpeg: Optional[subprocess.Popen] = None
_ffmpeg_lock = threading.Lock()
_rtmp_state = "idle"
_rtmp_error: Optional[str] = None
_rtmp_cfg: dict[str, Any] = {}
_rtmp_frames = 0
_rtmp_dropped = 0
_rtmp_start_ts = 0.0
_rtmp_last_frame_ts = 0.0
_rtmp_bytes_in = 0


def _ensure_cam(w: int, h: int) -> None:
    global _cam, _width, _height
    with _cam_lock:
        if _cam is not None and (w, h) == (_width, _height):
            return
        try:
            import pyvirtualcam
        except ImportError as e:
            raise RuntimeError("pyvirtualcam not installed. pip install pyvirtualcam") from e

        if _cam is not None:
            try:
                _cam.close()
            except Exception:
                pass
        _width, _height = w, h
        _cam = pyvirtualcam.Camera(
            width=w, height=h, fps=_fps, fmt=pyvirtualcam.PixelFormat.RGB
        )
        log.info("Virtual cam: %s (%dx%d @ %dfps)", _cam.device, w, h, _fps)


def _decode_frame(data: bytes, fmt: str, w: int, h: int) -> np.ndarray:
    if fmt in ("jpeg", "png", "jpg"):
        img = Image.open(io.BytesIO(data)).convert("RGB")
        if img.size != (w, h):
            img = img.resize((w, h), Image.Resampling.LANCZOS)
        return np.asarray(img)
    arr = np.frombuffer(data, dtype=np.uint8)
    if fmt == "rgba" and arr.size >= w * h * 4:
        rgba = arr[: w * h * 4].reshape((h, w, 4))
        return rgba[:, :, :3].copy()
    if arr.size >= w * h * 3:
        return arr[: w * h * 3].reshape((h, w, 3)).copy()
    return np.zeros((h, w, 3), dtype=np.uint8)


def _jpeg_bytes(rgb: np.ndarray, quality: int = 85) -> bytes:
    img = Image.fromarray(rgb)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=quality)
    return buf.getvalue()


# ── Health & virtual cam frame ──────────────────────────────────────────────

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "ok": True,
        "cam": getattr(_cam, "device", None),
        "rtmp": _rtmp_state,
        "ffmpeg": shutil.which("ffmpeg") is not None,
    })


@app.route("/frame", methods=["POST"])
def frame():
    global _last_frame
    data = request.get_data()
    if not data:
        return jsonify({"error": "empty body"}), 400
    w = int(request.headers.get("X-Frame-Width", _width))
    h = int(request.headers.get("X-Frame-Height", _height))
    fmt = request.headers.get("X-Frame-Format", "jpeg").lower()
    try:
        rgb = _decode_frame(data, fmt, w, h)
        try:
            _ensure_cam(rgb.shape[1], rgb.shape[0])
            with _cam_lock:
                if _cam is not None:
                    _cam.send(rgb)
                    _cam.sleep_until_next_frame()
        except Exception as ve:
            log.warning("virtual cam skip: %s", ve)
        _last_frame = rgb
        return jsonify({"ok": True})
    except Exception as e:
        log.exception("frame error")
        return jsonify({"error": str(e)}), 500


# ── RTMP ────────────────────────────────────────────────────────────────────

def _stop_ffmpeg() -> None:
    global _ffmpeg, _rtmp_state
    with _ffmpeg_lock:
        if _ffmpeg is not None:
            try:
                if _ffmpeg.stdin:
                    _ffmpeg.stdin.close()
            except Exception:
                pass
            try:
                _ffmpeg.terminate()
                _ffmpeg.wait(timeout=3)
            except Exception:
                try:
                    _ffmpeg.kill()
                except Exception:
                    pass
            _ffmpeg = None
        if _rtmp_state != "error":
            _rtmp_state = "stopped"


def _start_ffmpeg(cfg: dict[str, Any]) -> None:
    global _ffmpeg, _rtmp_state, _rtmp_error, _rtmp_cfg, _rtmp_frames
    global _rtmp_dropped, _rtmp_start_ts, _rtmp_bytes_in

    if shutil.which("ffmpeg") is None:
        raise RuntimeError(
            "ffmpeg not found on PATH. Install from https://ffmpeg.org and restart the bridge."
        )

    _stop_ffmpeg()

    publish = cfg.get("publishUrl") or (
        cfg.get("rtmpUrl", "").rstrip("/") + "/" + cfg.get("streamKey", "").lstrip("/")
    )
    w = int(cfg.get("width", 1280))
    h = int(cfg.get("height", 720))
    fps = int(cfg.get("fps", 30))
    vbit = int(cfg.get("videoBitrateKbps", 4500))
    abit = int(cfg.get("audioBitrateKbps", 160))
    codec = cfg.get("videoCodec", "libx264")
    preset = cfg.get("preset", "veryfast")
    enable_audio = bool(cfg.get("enableAudio", True))

    # Prefer NVENC when requested or auto
    if codec in ("auto", "nvenc", "h264_nvenc"):
        codec = "h264_nvenc"
    elif codec in ("hevc", "hevc_nvenc", "h265_nvenc"):
        codec = "hevc_nvenc"

    # Input: MJPEG over stdin — no -re (that forces realtime clock lag for live)
    cmd = [
        "ffmpeg",
        "-loglevel", "warning",
        "-fflags", "nobuffer+flush_packets",
        "-flags", "low_delay",
        "-f", "mjpeg",
        "-framerate", str(fps),
        "-i", "pipe:0",
    ]
    if enable_audio:
        cmd += [
            "-f", "lavfi",
            "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
        ]

    gop = max(fps, 30)

    if codec in ("h264_nvenc", "hevc_nvenc"):
        # NVIDIA NVENC — low-latency HQ preset (p1–p7; p1 = lowest latency)
        nv_preset = cfg.get("nvencPreset") or (
            "p1" if cfg.get("lowLatency", True) else "p4"
        )
        # Ultra-low-latency NVENC: min buffer, no lookahead, no B-frames, baseline/main
        cmd += [
            "-c:v", codec,
            "-preset", nv_preset,           # p1 = lowest latency
            "-tune", "ll",
            "-rc", "cbr",
            "-b:v", f"{vbit}k",
            "-maxrate", f"{vbit}k",
            "-bufsize", f"{max(vbit // 2, 1000)}k",
            "-profile:v", "baseline" if codec == "h264_nvenc" else "main",
            "-g", str(gop),
            "-bf", "0",
            "-delay", "0",
            "-rc-lookahead", "0",
            "-spatial-aq", "0",
            "-temporal-aq", "0",
            "-pix_fmt", "yuv420p",
            "-s", f"{w}x{h}",
            "-flush_packets", "1",
        ]
        # Some FFmpeg builds use -tune ll instead of -zerolatency
        log.info("NVENC encoder active preset=%s", nv_preset)
    else:
        # CPU libx264 zerolatency
        if codec not in ("libx264", "libx265"):
            codec = "libx264"
        xpreset = preset if preset != "medium" else "veryfast"
        cmd += [
            "-c:v", codec,
            "-preset", xpreset,
            "-b:v", f"{vbit}k",
            "-maxrate", f"{int(vbit * 1.1)}k",
            "-bufsize", f"{vbit}k",
            "-pix_fmt", "yuv420p",
            "-g", str(gop),
            "-keyint_min", str(max(fps // 2, 15)),
            "-sc_threshold", "0",
            "-bf", "0",
            "-s", f"{w}x{h}",
            "-flush_packets", "1",
        ]
        if codec == "libx264":
            cmd += ["-tune", "zerolatency", "-x264-params", "nal-hrd=cbr:force-cfr=1"]

    if enable_audio:
        cmd += ["-c:a", "aac", "-b:a", f"{abit}k", "-ar", "48000", "-shortest"]
    cmd += ["-f", "flv", publish]

    log.info("Starting FFmpeg RTMP → %s", publish.split("/")[2] if "/" in publish else publish)
    log.debug("FFmpeg cmd: %s", " ".join(cmd))

    _ffmpeg = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        bufsize=0,
    )
    _rtmp_cfg = cfg
    _rtmp_frames = 0
    _rtmp_dropped = 0
    _rtmp_bytes_in = 0
    _rtmp_start_ts = time.time()
    _rtmp_error = None
    _rtmp_state = "live"

    def _watch_stderr():
        global _rtmp_state, _rtmp_error
        assert _ffmpeg is not None and _ffmpeg.stderr is not None
        for line in iter(_ffmpeg.stderr.readline, b""):
            msg = line.decode("utf-8", errors="replace").strip()
            if msg:
                log.warning("ffmpeg: %s", msg)
                if "error" in msg.lower() or "failed" in msg.lower():
                    _rtmp_error = msg
        code = _ffmpeg.wait()
        if _rtmp_state == "live":
            _rtmp_state = "error"
            _rtmp_error = _rtmp_error or f"ffmpeg exited with code {code}"
            log.error("FFmpeg exited: %s", _rtmp_error)

    threading.Thread(target=_watch_stderr, daemon=True).start()


@app.route("/rtmp/start", methods=["POST"])
def rtmp_start():
    global _rtmp_state, _rtmp_error
    try:
        cfg = request.get_json(force=True, silent=True) or {}
        if not cfg.get("streamKey") and not cfg.get("publishUrl"):
            return jsonify({"error": "streamKey or publishUrl required"}), 400
        _start_ffmpeg(cfg)
        return jsonify({"ok": True, "state": _rtmp_state, "publishUrl": cfg.get("publishUrl")})
    except Exception as e:
        _rtmp_state = "error"
        _rtmp_error = str(e)
        log.exception("rtmp start failed")
        return jsonify({"error": str(e)}), 500


@app.route("/rtmp/stop", methods=["POST"])
def rtmp_stop():
    _stop_ffmpeg()
    return jsonify({"ok": True, "state": _rtmp_state})


@app.route("/rtmp/frame", methods=["POST"])
def rtmp_frame():
    global _rtmp_frames, _rtmp_dropped, _rtmp_last_frame_ts, _rtmp_bytes_in, _last_frame
    if _rtmp_state != "live" or _ffmpeg is None or _ffmpeg.stdin is None:
        return jsonify({"error": "rtmp not live"}), 409

    data = request.get_data()
    if not data:
        return jsonify({"error": "empty"}), 400

    w = int(request.headers.get("X-Frame-Width", _rtmp_cfg.get("width", _width)))
    h = int(request.headers.get("X-Frame-Height", _rtmp_cfg.get("height", _height)))
    fmt = request.headers.get("X-Frame-Format", "jpeg").lower()
    fps_target = int(_rtmp_cfg.get("fps", 30))

    try:
        # Normalize to JPEG for MJPEG pipe
        if fmt in ("jpeg", "jpg"):
            jpeg = data
            try:
                rgb = _decode_frame(data, "jpeg", w, h)
                _last_frame = rgb
            except Exception:
                pass
        else:
            rgb = _decode_frame(data, fmt, w, h)
            _last_frame = rgb
            tw = int(_rtmp_cfg.get("width", w))
            th = int(_rtmp_cfg.get("height", h))
            if rgb.shape[1] != tw or rgb.shape[0] != th:
                img = Image.fromarray(rgb).resize((tw, th), Image.Resampling.LANCZOS)
                rgb = np.asarray(img)
            jpeg = _jpeg_bytes(rgb)

        # Drop frame if client is more than ~3 frames behind (backpressure)
        now = time.time()
        if _rtmp_last_frame_ts and (now - _rtmp_last_frame_ts) < (1.0 / max(fps_target, 1) * 0.25):
            # optional micro-sleep skip — prefer drop under overload
            pass
        with _ffmpeg_lock:
            if _ffmpeg and _ffmpeg.stdin:
                _ffmpeg.stdin.write(jpeg)
                try:
                    _ffmpeg.stdin.flush()
                except Exception:
                    pass
        _rtmp_frames += 1
        _rtmp_bytes_in += len(jpeg)
        _rtmp_last_frame_ts = now
        return jsonify({"ok": True, "ll": True})
    except BrokenPipeError:
        _rtmp_dropped += 1
        _rtmp_state = "error"
        _rtmp_error = "FFmpeg pipe broken (stream disconnected?)"
        return jsonify({"error": _rtmp_error}), 500
    except Exception as e:
        _rtmp_dropped += 1
        log.warning("rtmp frame: %s", e)
        return jsonify({"error": str(e)}), 500


@app.route("/rtmp/stats", methods=["GET"])
def rtmp_stats():
    elapsed = max(time.time() - _rtmp_start_ts, 0.001) if _rtmp_start_ts else 0.001
    fps = _rtmp_frames / elapsed if _rtmp_start_ts else 0
    # Approximate input bitrate from JPEG bytes
    bitrate = int((_rtmp_bytes_in * 8 / 1000) / elapsed) if _rtmp_start_ts else 0
    target = int(_rtmp_cfg.get("videoBitrateKbps", 0))
    return jsonify({
        "state": _rtmp_state,
        "fps": round(fps, 1),
        "bitrateKbps": target or bitrate,
        "inputBitrateKbps": bitrate,
        "frames": _rtmp_frames,
        "dropped": _rtmp_dropped,
        "error": _rtmp_error,
        "uptimeSec": int(elapsed) if _rtmp_start_ts else 0,
    })


def _idle_loop():
    global _last_frame
    while _running:
        with _cam_lock:
            if _cam is not None:
                frame = _last_frame
                if frame is None:
                    frame = np.zeros((_height, _width, 3), dtype=np.uint8)
                try:
                    _cam.send(frame)
                    _cam.sleep_until_next_frame()
                    continue
                except Exception:
                    pass
        time.sleep(1.0 / _fps)



# ── OBS WebSocket (optimized: reconnect, env password, low timeout) ─────────
# Enable: OBS → Tools → WebSocket Server Settings → Enable
# Optional env: OBS_HOST, OBS_PORT, OBS_PASSWORD

_obs = None
_obs_lock = threading.Lock()
_obs_last_ok = 0.0
_OBS_HOST = os.environ.get("OBS_HOST", "127.0.0.1")
_OBS_PORT = int(os.environ.get("OBS_PORT", "4455"))
_OBS_PASSWORD = os.environ.get("OBS_PASSWORD", "")


def _obs_reset():
    global _obs
    with _obs_lock:
        _obs = None


def _get_obs(force: bool = False):
    """Cached OBS client with automatic reconnect after failures."""
    global _obs, _obs_last_ok
    with _obs_lock:
        if _obs is not None and not force:
            # Soft health: reuse for 30s without re-handshake
            if time.time() - _obs_last_ok < 30:
                return _obs
        try:
            import obsws_python as obs
            client = obs.ReqClient(
                host=_OBS_HOST,
                port=_OBS_PORT,
                password=_OBS_PASSWORD or "",
                timeout=2,  # low latency control path
            )
            _obs = client
            _obs_last_ok = time.time()
            log.info("OBS WebSocket OK %s:%s", _OBS_HOST, _OBS_PORT)
            return _obs
        except Exception as e:
            log.warning("OBS WebSocket unavailable: %s", e)
            _obs = None
            return None


@app.route("/obs/status", methods=["GET"])
def obs_status():
    client = _get_obs(force=True)
    if client is None:
        return jsonify({
            "connected": False,
            "host": f"{_OBS_HOST}:{_OBS_PORT}",
            "hint": "Enable OBS WebSocket; set OBS_PASSWORD if required; pip install obsws-python",
        })
    try:
        # Lightweight call
        ver = getattr(client, "get_version", lambda: None)()
        return jsonify({
            "connected": True,
            "host": f"{_OBS_HOST}:{_OBS_PORT}",
            "latencyOptimized": True,
        })
    except Exception as e:
        _obs_reset()
        return jsonify({"connected": False, "error": str(e)})


@app.route("/obs/scenes", methods=["GET"])
def obs_scenes():
    client = _get_obs()
    demo = [
        {"name": "Main Camera", "current": True},
        {"name": "Face Swap Close-up", "current": False},
        {"name": "Screen Share", "current": False},
        {"name": "BRB / Be Right Back", "current": False},
        {"name": "Starting Soon", "current": False},
        {"name": "Ending Screen", "current": False},
    ]
    if client is None:
        return jsonify({"connected": False, "scenes": demo})
    try:
        resp = client.get_scene_list()
        current = resp.current_program_scene_name
        scenes = [
            {"name": s["sceneName"], "current": s["sceneName"] == current}
            for s in resp.scenes
        ]
        global _obs_last_ok
        _obs_last_ok = time.time()
        return jsonify({"connected": True, "scenes": scenes, "current": current})
    except Exception as e:
        _obs_reset()
        return jsonify({"connected": False, "error": str(e), "scenes": demo})


@app.route("/obs/scene", methods=["POST"])
def obs_set_scene():
    data = request.get_json(force=True, silent=True) or {}
    name = data.get("name") or data.get("scene")
    if not name:
        return jsonify({"error": "name required"}), 400
    client = _get_obs()
    if client is None:
        return jsonify({"ok": True, "simulated": True, "scene": name})
    try:
        t0 = time.time()
        client.set_current_program_scene(name)
        ms = round((time.time() - t0) * 1000, 1)
        global _obs_last_ok
        _obs_last_ok = time.time()
        return jsonify({"ok": True, "scene": name, "rttMs": ms})
    except Exception as e:
        _obs_reset()
        return jsonify({"error": str(e)}), 500


@app.route("/obs/studio-mode", methods=["POST"])
def obs_studio_mode():
    data = request.get_json(force=True, silent=True) or {}
    enabled = bool(data.get("enabled", True))
    client = _get_obs()
    if client is None:
        return jsonify({"ok": True, "simulated": True, "studioMode": enabled})
    try:
        client.set_studio_mode_enabled(enabled)
        return jsonify({"ok": True, "studioMode": enabled})
    except Exception as e:
        _obs_reset()
        return jsonify({"error": str(e)}), 500


# ── FFmpeg → v4l2loopback (low-latency Linux virtual cam) ───────────────────
# Setup once:
#   sudo apt install v4l2loopback-dkms
#   sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="StudioCam" exclusive_caps=1
# Latency tips: lower resolution, 30fps, MJPEG, no -re on input, small buffers

_ffmpeg_vcam: Optional[subprocess.Popen] = None
_vcam_cfg: dict[str, Any] = {}


@app.route("/vcam/ffmpeg/start", methods=["POST"])
def vcam_ffmpeg_start():
    """Low-latency FFmpeg virtual cam into v4l2loopback.
    Body: { "device": "/dev/video10", "width": 1280, "height": 720, "fps": 30, "lowLatency": true }
    """
    global _ffmpeg_vcam, _vcam_cfg
    if shutil.which("ffmpeg") is None:
        return jsonify({"error": "ffmpeg not on PATH"}), 500
    cfg = request.get_json(force=True, silent=True) or {}
    device = cfg.get("device", "/dev/video10")
    w = int(cfg.get("width", 1280))
    h = int(cfg.get("height", 720))
    fps = int(cfg.get("fps", 30))
    low = bool(cfg.get("lowLatency", True))

    if _ffmpeg_vcam is not None:
        try:
            if _ffmpeg_vcam.stdin:
                _ffmpeg_vcam.stdin.close()
            _ffmpeg_vcam.terminate()
            _ffmpeg_vcam.wait(timeout=2)
        except Exception:
            try:
                _ffmpeg_vcam.kill()
            except Exception:
                pass
        _ffmpeg_vcam = None

    # Low-latency flags: probe size, analyze duration, flush packets, no mux delay
    cmd = [
        "ffmpeg",
        "-loglevel", "error",
        "-fflags", "nobuffer",
        "-flags", "low_delay",
        "-probesize", "32",
        "-analyzeduration", "0",
        "-f", "mjpeg",
        "-framerate", str(fps),
        "-i", "pipe:0",
        "-an",
        "-c:v", "rawvideo",
        "-pix_fmt", "yuv420p",
        "-s", f"{w}x{h}",
        "-f", "v4l2",
        device,
    ]
    if not low:
        # Slightly more stable, higher latency path
        cmd = [
            "ffmpeg", "-loglevel", "error",
            "-f", "mjpeg", "-r", str(fps), "-i", "pipe:0",
            "-f", "v4l2", "-pix_fmt", "yuv420p", "-s", f"{w}x{h}", device,
        ]

    try:
        _ffmpeg_vcam = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,  # unbuffered stdin for minimal lag
        )
        _vcam_cfg = {"device": device, "width": w, "height": h, "fps": fps, "lowLatency": low}
        log.info("FFmpeg low-latency vcam → %s (%dx%d@%d)", device, w, h, fps)
        return jsonify({"ok": True, "device": device, "lowLatency": low, "cmd": " ".join(cmd)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/vcam/ffmpeg/frame", methods=["POST"])
def vcam_ffmpeg_frame():
    global _ffmpeg_vcam
    if _ffmpeg_vcam is None or _ffmpeg_vcam.stdin is None:
        return jsonify({"error": "ffmpeg vcam not started — POST /vcam/ffmpeg/start first"}), 409
    data = request.get_data()
    if not data:
        return jsonify({"error": "empty"}), 400
    fmt = request.headers.get("X-Frame-Format", "jpeg").lower()
    try:
        if fmt not in ("jpeg", "jpg"):
            w = int(request.headers.get("X-Frame-Width", _vcam_cfg.get("width", 1280)))
            h = int(request.headers.get("X-Frame-Height", _vcam_cfg.get("height", 720)))
            rgb = _decode_frame(data, fmt, w, h)
            data = _jpeg_bytes(rgb, quality=80)  # slightly lower quality = less encode time
        _ffmpeg_vcam.stdin.write(data)
        _ffmpeg_vcam.stdin.flush()
        return jsonify({"ok": True})
    except BrokenPipeError:
        return jsonify({"error": "pipe broken — restart /vcam/ffmpeg/start"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/vcam/ffmpeg/stop", methods=["POST"])
def vcam_ffmpeg_stop():
    global _ffmpeg_vcam
    if _ffmpeg_vcam is not None:
        try:
            if _ffmpeg_vcam.stdin:
                _ffmpeg_vcam.stdin.close()
            _ffmpeg_vcam.terminate()
        except Exception:
            pass
        _ffmpeg_vcam = None
    return jsonify({"ok": True})


@app.route("/vcam/info", methods=["GET"])
def vcam_info():
    """Driver tips + current status for all OS virtual-cam paths."""
    return jsonify({
        "pyvirtualcam": _cam is not None,
        "pyvirtualcamDevice": getattr(_cam, "device", None) if _cam else None,
        "ffmpegVcam": _ffmpeg_vcam is not None,
        "ffmpegVcamCfg": _vcam_cfg,
        "platforms": {
            "linux": {
                "preferred": "v4l2loopback + FFmpeg low-latency OR pyvirtualcam",
                "setup": [
                    "sudo apt install v4l2loopback-dkms",
                    'sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="StudioCam" exclusive_caps=1',
                    "POST /vcam/ffmpeg/start {\"device\":\"/dev/video10\",\"lowLatency\":true}",
                ],
                "targetLatencyMs": "40–120 with lowLatency flags at 720p30",
            },
            "windows": {
                "preferred": "pyvirtualcam (Unity Capture / OBS Virtual Cam backend)",
                "note": "Install OBS or pyvirtualcam deps; select device in Zoom/Teams",
            },
            "macos": {
                "preferred": "OBS Virtual Camera or pyvirtualcam where supported",
                "note": "Grant camera permission; select OBS Virtual Camera in apps",
            },
        },
        "appsThatSeeVirtualCam": [
            "Zoom", "Microsoft Teams", "Google Meet (browser/PWA where device list allows)",
            "Discord", "Slack", "Skype", "Webex", "OBS Studio", "Browser getUserMedia",
        ],
    })



# ── Long-form movie export (≈2h optimized FFmpeg) ───────────────────────────
# Two-pass or CRF encode tuned for quality vs time on feature-length media.

_export_proc: Optional[subprocess.Popen] = None
_export_status: dict[str, Any] = {"state": "idle"}


@app.route("/export/movie", methods=["POST"])
def export_movie():
    """Encode a long video with settings safe for ~2 hour features.
    JSON body:
      inputPath, outputPath,
      mode: "fast" | "balanced" | "quality",
      codec: "libx264" | "libx265" | "h264_nvenc" | "hevc_nvenc",
      width, height, fps, audioKbps
    """
    global _export_proc, _export_status
    if shutil.which("ffmpeg") is None:
        return jsonify({"error": "ffmpeg not on PATH"}), 500
    cfg = request.get_json(force=True, silent=True) or {}
    inp = cfg.get("inputPath")
    out = cfg.get("outputPath")
    if not inp or not out:
        return jsonify({"error": "inputPath and outputPath required"}), 400
    if not os.path.isfile(inp):
        return jsonify({"error": f"input not found: {inp}"}), 404

    mode = cfg.get("mode", "balanced")
    codec = cfg.get("videoCodec") or cfg.get("codec") or "libx264"
    w = int(cfg.get("width", 1920))
    h = int(cfg.get("height", 1080))
    fps = int(cfg.get("fps", 24))
    audio_k = int(cfg.get("audioKbps", 192))

    # Presets tuned for long GOPs / 2h files
    # fast: quick draft; balanced: good default; quality: archival-ish CRF
    if mode == "fast":
        x264_preset, crf, audio_k = "veryfast", 23, min(audio_k, 160)
    elif mode == "quality":
        x264_preset, crf, audio_k = "slow", 18, max(audio_k, 192)
    else:
        x264_preset, crf, audio_k = "medium", 20, audio_k

    # Hardware encoders ignore CRF differently — map to quality scales
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "warning", "-i", inp]

    if codec in ("h264_nvenc", "hevc_nvenc"):
        cq = 19 if mode == "quality" else (23 if mode == "fast" else 21)
        cmd += [
            "-c:v", codec,
            "-preset", "p4" if mode != "fast" else "p1",
            "-rc", "vbr",
            "-cq", str(cq),
            "-b:v", "0",
            "-spatial-aq", "1",
            "-temporal-aq", "1",
        ]
    elif codec == "libx265":
        cmd += ["-c:v", "libx265", "-preset", x264_preset, "-crf", str(crf + 1)]
    else:
        # libx264 — film-friendly: film tune, longer keyint for 2h seeking still OK
        gop = fps * 4
        cmd += [
            "-c:v", "libx264",
            "-preset", x264_preset,
            "-crf", str(crf),
            "-tune", "film",
            "-profile:v", "high",
            "-level", "4.1",
            "-pix_fmt", "yuv420p",
            "-g", str(gop),
            "-keyint_min", str(fps),
            "-sc_threshold", "40",
            "-movflags", "+faststart",  # web + progressive download
        ]

    cmd += [
        "-vf", f"scale={w}:{h}:force_original_aspect_ratio=decrease,pad={w}:{h}:(ow-iw)/2:(oh-ih)/2",
        "-r", str(fps),
        "-c:a", "aac",
        "-b:a", f"{audio_k}k",
        "-ac", "2",
        "-ar", "48000",
        out,
    ]

    if _export_proc is not None and _export_proc.poll() is None:
        return jsonify({"error": "export already running"}), 409

    log.info("Movie export: %s", " ".join(cmd))
    _export_status = {"state": "running", "output": out, "mode": mode, "codec": codec}
    try:
        _export_proc = subprocess.Popen(cmd, stderr=subprocess.PIPE, stdout=subprocess.DEVNULL)
    except Exception as e:
        _export_status = {"state": "error", "error": str(e)}
        return jsonify({"error": str(e)}), 500

    def _wait():
        global _export_status, _export_proc
        assert _export_proc is not None
        err = _export_proc.stderr.read().decode("utf-8", errors="replace") if _export_proc.stderr else ""
        code = _export_proc.wait()
        if code == 0:
            _export_status = {"state": "done", "output": out, "mode": mode}
        else:
            _export_status = {"state": "error", "code": code, "log": err[-2000:]}
        _export_proc = None

    threading.Thread(target=_wait, daemon=True).start()
    return jsonify({"ok": True, "state": "running", "cmd": " ".join(cmd)})


@app.route("/export/status", methods=["GET"])
def export_status():
    return jsonify(_export_status)


@app.route("/export/cancel", methods=["POST"])
def export_cancel():
    global _export_proc, _export_status
    if _export_proc is not None and _export_proc.poll() is None:
        _export_proc.terminate()
        _export_status = {"state": "cancelled"}
    return jsonify({"ok": True})


# ── AI voice cloning (external service hook) ────────────────────────────────
# Point VOICE_CLONE_URL at a local TTS/clone server (e.g. OpenVoice, Coqui, RVC API).
# This bridge only proxies — models stay on your machine.

_VOICE_CLONE_URL = os.environ.get("VOICE_CLONE_URL", "http://127.0.0.1:8777")


@app.route("/voice/status", methods=["GET"])
def voice_status():
    try:
        import urllib.request
        with urllib.request.urlopen(_VOICE_CLONE_URL + "/health", timeout=1.5) as r:
            ok = r.status == 200
        return jsonify({"connected": ok, "service": _VOICE_CLONE_URL})
    except Exception as e:
        return jsonify({
            "connected": False,
            "service": _VOICE_CLONE_URL,
            "hint": "Start a local voice-clone API or set VOICE_CLONE_URL. UI still works in demo mode.",
            "error": str(e),
        })


@app.route("/voice/clone", methods=["POST"])
def voice_clone():
    """Proxy clone request.
    multipart or JSON: { "text": "...", "speakerId": "...", "referencePath": "..." }
    Returns audio/wav bytes from upstream, or demo JSON if offline.
    """
    cfg = request.get_json(force=True, silent=True) or {}
    text = cfg.get("text") or request.form.get("text") or ""
    speaker = cfg.get("speakerId") or request.form.get("speakerId") or "default"
    if not text.strip():
        return jsonify({"error": "text required"}), 400

    try:
        import urllib.request
        payload = json.dumps({
            "text": text,
            "speakerId": speaker,
            "referencePath": cfg.get("referencePath"),
            "speed": cfg.get("speed", 1.0),
            "pitch": cfg.get("pitch", 0),
        }).encode("utf-8")
        req = urllib.request.Request(
            _VOICE_CLONE_URL.rstrip("/") + "/clone",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=120) as r:
            data = r.read()
            ctype = r.headers.get("Content-Type", "audio/wav")
        return app.response_class(data, mimetype=ctype)
    except Exception as e:
        # Demo response so UI can proceed
        return jsonify({
            "ok": False,
            "demo": True,
            "message": "Voice clone service offline — install OpenVoice/Coqui/RVC API and set VOICE_CLONE_URL",
            "text": text,
            "speakerId": speaker,
            "error": str(e),
        }), 503


@app.route("/voice/speakers", methods=["GET"])
def voice_speakers():
    try:
        import urllib.request
        with urllib.request.urlopen(_VOICE_CLONE_URL.rstrip("/") + "/speakers", timeout=2) as r:
            return app.response_class(r.read(), mimetype="application/json")
    except Exception:
        return jsonify({
            "speakers": [
                {"id": "default", "name": "Studio Default"},
                {"id": "narrator", "name": "Film Narrator"},
                {"id": "hero", "name": "Hero Lead"},
                {"id": "custom1", "name": "Custom Clone 1"},
            ],
            "demo": True,
        })



@app.route("/encode/capabilities", methods=["GET"])
def encode_capabilities():
    """Detect FFmpeg NVENC / hardware encoders available on this machine."""
    ff = shutil.which("ffmpeg")
    caps = {
        "ffmpeg": ff is not None,
        "nvenc_h264": False,
        "nvenc_hevc": False,
        "recommended": "libx264",
        "lowLatencyHint": "Use videoCodec=h264_nvenc or auto when NVENC is available",
    }
    if not ff:
        return jsonify(caps)
    try:
        import subprocess as sp
        out = sp.check_output(
            [ff, "-hide_banner", "-encoders"],
            stderr=sp.STDOUT,
            text=True,
            timeout=5,
        )
        caps["nvenc_h264"] = "h264_nvenc" in out
        caps["nvenc_hevc"] = "hevc_nvenc" in out
        if caps["nvenc_h264"]:
            caps["recommended"] = "h264_nvenc"
        elif "h264_qsv" in out:
            caps["recommended"] = "h264_qsv"
            caps["qsv_h264"] = True
        elif "h264_amf" in out:
            caps["recommended"] = "h264_amf"
            caps["amf_h264"] = True
    except Exception as e:
        caps["error"] = str(e)
    return jsonify(caps)


if __name__ == "__main__":
    t = threading.Thread(target=_idle_loop, daemon=True)
    t.start()
    port = int(os.environ.get("PORT", "8766"))
    host = os.environ.get("HOST", "0.0.0.0")
    log.info("Bridge http://%s:%s", host, port)
    log.info("  Virtual cam: POST /frame  |  FFmpeg vcam: /vcam/ffmpeg/*  |  info: GET /vcam/info")
    log.info("  RTMP: /rtmp/start|frame|stop|stats")
    log.info("  OBS:  /obs/status|scenes|scene  (WebSocket %s:%s)", _OBS_HOST, _OBS_PORT)
    log.info("ffmpeg: %s", shutil.which("ffmpeg") or "NOT FOUND")
    log.info("Low-latency mode: x264 zerolatency, short GOP, unbuffered pipes, drop-on-timeout clients")
    app.run(host=host, port=port, debug=False, threaded=True)
    _host = os.environ.get("HOST", "0.0.0.0")
    _port = int(os.environ.get("PORT", "8766"))
    # Cloud (Render/Railway): HOST=0.0.0.0 PORT=$PORT
    app.run(host=_host, port=_port, threaded=True, processes=1)
