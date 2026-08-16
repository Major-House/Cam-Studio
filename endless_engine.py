#!/usr/bin/env python3
"""
ENDLESS CAM / STUDIO — Real production engine
=============================================
This is NOT a demo. It captures a real webcam and continuously outputs to:

  1) System virtual camera  (pyvirtualcam / v4l2)  → Zoom, Teams, Discord, OBS
  2) RTMP live              (FFmpeg + optional NVENC) → Twitch, YouTube, TikTok
  3) Optional MJPEG preview HTTP for the UI

Requirements:
  pip install opencv-python-headless numpy pyvirtualcam flask pillow
  FFmpeg on PATH  |  Linux v4l2loopback optional for /dev/videoN

Usage:
  python endless_engine.py
  python endless_engine.py --camera 0 --width 1280 --height 720 --fps 30
  python endless_engine.py --rtmp rtmp://live.twitch.tv/app/YOUR_KEY --nvenc
  python endless_engine.py --no-vcam --rtmp rtmp://...   # RTMP only

Press Q in the preview window to quit (if --preview).
"""

from __future__ import annotations

import argparse
import logging
import os
import shutil
import signal
import subprocess
import sys
import threading
import time
from typing import Optional

import cv2
import numpy as np

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("endless")

# ── Virtual camera ──────────────────────────────────────────────────────────
_vcam = None


def start_vcam(width: int, height: int, fps: int, device: Optional[str]):
    global _vcam
    try:
        import pyvirtualcam
    except ImportError:
        log.error("pyvirtualcam not installed: pip install pyvirtualcam")
        return None
    kwargs = dict(width=width, height=height, fps=fps, fmt=pyvirtualcam.PixelFormat.BGR)
    # Backend hints
    if sys.platform == "linux" and device:
        os.environ.setdefault("PYVIRTUALCAM_DEVICE", device)
    try:
        _vcam = pyvirtualcam.Camera(**kwargs)
        log.info("Virtual camera ON → %s (%dx%d@%d)", _vcam.device, width, height, fps)
        return _vcam
    except Exception as e:
        log.error("Virtual camera failed: %s", e)
        log.error(
            "Linux: sudo modprobe v4l2loopback devices=1 video_nr=10 "
            'card_label="EndlessCam" exclusive_caps=1'
        )
        log.error("Windows/macOS: install OBS Virtual Cam or pyvirtualcam backend")
        return None


def send_vcam(frame_bgr: np.ndarray):
    if _vcam is None:
        return
    try:
        h, w = frame_bgr.shape[:2]
        if w != _vcam.width or h != _vcam.height:
            frame_bgr = cv2.resize(frame_bgr, (_vcam.width, _vcam.height))
        _vcam.send(frame_bgr)
        _vcam.sleep_until_next_frame()
    except Exception as e:
        log.warning("vcam send: %s", e)


# ── RTMP via FFmpeg ─────────────────────────────────────────────────────────
_ffmpeg: Optional[subprocess.Popen] = None


def start_rtmp(
    url: str,
    width: int,
    height: int,
    fps: int,
    bitrate: int,
    nvenc: bool,
):
    global _ffmpeg
    if not shutil.which("ffmpeg"):
        log.error("ffmpeg not on PATH — cannot RTMP")
        return False
    stop_rtmp()

    codec = "h264_nvenc" if nvenc else "libx264"
    cmd = [
        "ffmpeg",
        "-loglevel", "error",
        "-fflags", "nobuffer",
        "-flags", "low_delay",
        "-f", "rawvideo",
        "-pix_fmt", "bgr24",
        "-s", f"{width}x{height}",
        "-r", str(fps),
        "-i", "-",
        "-an",
        "-c:v", codec,
        "-b:v", f"{bitrate}k",
        "-maxrate", f"{bitrate}k",
        "-bufsize", f"{bitrate}k",
        "-g", str(fps),
        "-bf", "0",
        "-pix_fmt", "yuv420p",
        "-f", "flv",
        url,
    ]
    if codec == "libx264":
        cmd[cmd.index("-c:v") + 2 : cmd.index("-c:v") + 2] = []  # noop guard
        # insert after -c:v libx264
        i = cmd.index("libx264")
        cmd[i + 1 : i + 1] = ["-preset", "veryfast", "-tune", "zerolatency"]
    elif codec == "h264_nvenc":
        i = cmd.index("h264_nvenc")
        cmd[i + 1 : i + 1] = ["-preset", "p1", "-rc", "cbr", "-delay", "0"]

    log.info("RTMP starting (%s) → %s", codec, url.split("/")[2] if "://" in url else url)
    try:
        _ffmpeg = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            bufsize=0,
        )
        return True
    except Exception as e:
        log.error("FFmpeg start failed: %s", e)
        _ffmpeg = None
        return False


def send_rtmp(frame_bgr: np.ndarray):
    global _ffmpeg
    if _ffmpeg is None or _ffmpeg.stdin is None:
        return
    try:
        _ffmpeg.stdin.write(frame_bgr.tobytes())
    except BrokenPipeError:
        log.error("RTMP pipe broken — stream ended")
        _ffmpeg = None
    except Exception as e:
        log.warning("RTMP write: %s", e)


def stop_rtmp():
    global _ffmpeg
    if _ffmpeg is not None:
        try:
            if _ffmpeg.stdin:
                _ffmpeg.stdin.close()
            _ffmpeg.terminate()
            _ffmpeg.wait(timeout=3)
        except Exception:
            try:
                _ffmpeg.kill()
            except Exception:
                pass
        _ffmpeg = None
        log.info("RTMP stopped")


# ── Simple overlays (real pixels, not UI mock) ──────────────────────────────
def draw_live_badge(frame: np.ndarray, label: str = "ENDLESS CAM") -> np.ndarray:
    out = frame
    h, w = out.shape[:2]
    cv2.rectangle(out, (12, 12), (12 + 200, 44), (0, 0, 0), -1)
    cv2.circle(out, (28, 28), 7, (0, 0, 255), -1)
    cv2.putText(
        out,
        label,
        (44, 34),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.55,
        (255, 255, 255),
        1,
        cv2.LINE_AA,
    )
    cv2.putText(
        out,
        time.strftime("%H:%M:%S"),
        (w - 100, 34),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,
        (0, 230, 255),
        1,
        cv2.LINE_AA,
    )
    return out


def beautify_light(frame: np.ndarray, strength: float = 0.15) -> np.ndarray:
    """Cheap realtime look: slight contrast + warm lift — real pixel ops."""
    out = cv2.convertScaleAbs(frame, alpha=1.0 + strength * 0.3, beta=strength * 12)
    return out


# ── Main loop ───────────────────────────────────────────────────────────────
_running = True


def _sig(*_):
    global _running
    _running = False


def main():
    global _running
    ap = argparse.ArgumentParser(description="Endless Cam / Studio — real engine")
    ap.add_argument("--camera", type=int, default=0)
    ap.add_argument("--width", type=int, default=1280)
    ap.add_argument("--height", type=int, default=720)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--device", default=None, help="v4l2 device e.g. /dev/video10")
    ap.add_argument("--no-vcam", action="store_true")
    ap.add_argument("--rtmp", default=None, help="Full RTMP URL including stream key")
    ap.add_argument("--nvenc", action="store_true", help="Use NVIDIA h264_nvenc")
    ap.add_argument("--bitrate", type=int, default=4500)
    ap.add_argument("--preview", action="store_true", help="Show local OpenCV window")
    ap.add_argument("--no-overlay", action="store_true")
    args = ap.parse_args()

    signal.signal(signal.SIGINT, _sig)
    signal.signal(signal.SIGTERM, _sig)

    log.info("Opening camera %s …", args.camera)
    cap = cv2.VideoCapture(args.camera)
    if not cap.isOpened():
        log.error("Cannot open camera index %s", args.camera)
        log.error("Try --camera 1 or check OS camera permissions")
        sys.exit(1)

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, args.width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, args.height)
    cap.set(cv2.CAP_PROP_FPS, args.fps)
    # Reduce capture buffer lag where supported
    try:
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    except Exception:
        pass

    actual_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)) or args.width
    actual_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)) or args.height
    log.info("Camera open %dx%d @ ~%s fps", actual_w, actual_h, args.fps)

    if not args.no_vcam:
        start_vcam(actual_w, actual_h, args.fps, args.device)
        if _vcam is None:
            log.warning("Continuing without virtual camera")

    if args.rtmp:
        if not start_rtmp(args.rtmp, actual_w, actual_h, args.fps, args.bitrate, args.nvenc):
            log.warning("Continuing without RTMP")

    log.info("Endless loop running — Ctrl+C to stop")
    frames = 0
    t0 = time.time()

    while _running:
        ok, frame = cap.read()
        if not ok or frame is None:
            log.warning("Frame grab failed — retrying")
            time.sleep(0.05)
            continue

        if frame.shape[1] != actual_w or frame.shape[0] != actual_h:
            frame = cv2.resize(frame, (actual_w, actual_h))

        frame = beautify_light(frame)
        if not args.no_overlay:
            frame = draw_live_badge(frame)

        if not args.no_vcam:
            send_vcam(frame)
        if args.rtmp and _ffmpeg is not None:
            send_rtmp(frame)

        if args.preview:
            cv2.imshow("Endless Cam / Studio", frame)
            if cv2.waitKey(1) & 0xFF in (ord("q"), ord("Q")):
                break

        frames += 1
        if frames % (args.fps * 5) == 0:
            elapsed = time.time() - t0
            fps_m = frames / elapsed if elapsed > 0 else 0
            log.info(
                "frames=%d  ~%.1f fps  vcam=%s  rtmp=%s",
                frames,
                fps_m,
                "on" if _vcam else "off",
                "on" if _ffmpeg else "off",
            )

    log.info("Shutting down…")
    cap.release()
    stop_rtmp()
    if args.preview:
        cv2.destroyAllWindows()
    log.info("Stopped. Total frames %d", frames)


if __name__ == "__main__":
    main()
