#!/usr/bin/env python3
"""
Low-latency WebRTC video source for Hollywood Studio Pro
========================================================
Serves the studio frame stream over WebRTC (UDP/ICE) so browsers and
WebRTC clients get far lower latency than RTMP/CDN.

Requires: pip install aiortc av aiohttp opencv-python-headless numpy

Run:
  python webrtc_server.py
  # http://127.0.0.1:8787/  — demo player
  # POST /offer  — SDP exchange
  # POST /frame  — JPEG/raw frames from studio bridge or app

Design goals (low latency):
  - Single peer connection, no recording mux delay
  - Prefer VP8 or H264 if available; tune for realtime
  - Latest-frame wins (drop stale frames)
  - Local ICE only by default (no TURN unless configured)
"""

from __future__ import annotations

import argparse
import asyncio
import fractions
import json
import logging
import os
import time
from typing import Optional, Set

import numpy as np
from aiohttp import web

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("webrtc")

try:
    from aiortc import (
        RTCPeerConnection,
        RTCSessionDescription,
        VideoStreamTrack,
        RTCConfiguration,
        RTCIceServer,
    )
    from aiortc.mediastreams import MediaStreamError
    from av import VideoFrame
except ImportError as e:
    raise SystemExit(
        "Install WebRTC deps: pip install aiortc av aiohttp\n" + str(e)
    )

_pcs: Set[RTCPeerConnection] = set()
_latest_jpeg: Optional[bytes] = None
_latest_rgb: Optional[np.ndarray] = None
_frame_lock = asyncio.Lock()
_width = int(os.environ.get("WEBRTC_WIDTH", "1280"))
_height = int(os.environ.get("WEBRTC_HEIGHT", "720"))
_fps = int(os.environ.get("WEBRTC_FPS", "30"))


class LatestFrameTrack(VideoStreamTrack):
    """Emits the most recent studio frame; drops backlog for lowest latency."""

    kind = "video"

    def __init__(self) -> None:
        super().__init__()
        self._start = time.time()
        self._timestamp = 0
        # Black placeholder until first frame
        self._placeholder = np.zeros((_height, _width, 3), dtype=np.uint8)

    async def recv(self):
        pts, time_base = await self.next_timestamp()
        rgb = _latest_rgb
        if rgb is None and _latest_jpeg is not None:
            try:
                import cv2
                arr = np.frombuffer(_latest_jpeg, dtype=np.uint8)
                bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
                if bgr is not None:
                    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
                    if rgb.shape[1] != _width or rgb.shape[0] != _height:
                        rgb = cv2.resize(rgb, (_width, _height))
            except Exception:
                rgb = None
        if rgb is None:
            rgb = self._placeholder
        frame = VideoFrame.from_ndarray(rgb, format="rgb24")
        frame.pts = pts
        frame.time_base = time_base
        return frame

    async def next_timestamp(self):
        if hasattr(self, "_timestamp"):
            self._timestamp += int(90000 / _fps)
        else:
            self._timestamp = 0
        wait = 1.0 / _fps
        await asyncio.sleep(wait)
        return self._timestamp, fractions.Fraction(1, 90000)


async def index(request: web.Request) -> web.Response:
    html = f"""<!DOCTYPE html>
<html><head><meta charset=utf-8><title>Studio WebRTC</title>
<style>
body{{margin:0;background:#0a0a0f;color:#e8e6e3;font-family:system-ui}}
video{{width:100%;max-width:1280px;background:#000;display:block;margin:0 auto}}
.bar{{padding:12px 16px;background:#12121a;display:flex;gap:12px;align-items:center}}
button{{background:#c9a84c;border:0;padding:8px 16px;border-radius:6px;font-weight:700;cursor:pointer}}
.ok{{color:#3dd68c}}.bad{{color:#ff6b6b}}
</style></head><body>
<div class="bar">
  <strong>Hollywood Studio Pro · WebRTC</strong>
  <button id="go">Connect</button>
  <span id="st" class="bad">idle</span>
  <span>{_width}×{_height}@{_fps}</span>
</div>
<video id="v" autoplay playsinline muted></video>
<script>
const st = document.getElementById('st');
const v = document.getElementById('v');
document.getElementById('go').onclick = async () => {{
  st.textContent = 'negotiating…'; st.className = '';
  const pc = new RTCPeerConnection({{
    iceServers: [{{urls: 'stun:stun.l.google.com:19302'}}],
    bundlePolicy: 'max-bundle',
    rtcpMuxPolicy: 'require',
  }});
  pc.addTransceiver('video', {{direction: 'recvonly'}});
  pc.ontrack = (ev) => {{ v.srcObject = ev.streams[0]; st.textContent = 'live'; st.className = 'ok'; }};
  pc.oniceconnectionstatechange = () => {{ st.textContent = pc.iceConnectionState; }};
  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);
  const res = await fetch('/offer', {{
    method: 'POST',
    headers: {{'Content-Type': 'application/json'}},
    body: JSON.stringify({{sdp: pc.localDescription.sdp, type: pc.localDescription.type}}),
  }});
  const answer = await res.json();
  await pc.setRemoteDescription(answer);
}};
</script></body></html>"""
    return web.Response(text=html, content_type="text/html")


async def offer(request: web.Request) -> web.Response:
    params = await request.json()
    offer = RTCSessionDescription(sdp=params["sdp"], type=params["type"])

    config = RTCConfiguration(
        iceServers=[RTCIceServer(urls=["stun:stun.l.google.com:19302"])]
    )
    pc = RTCPeerConnection(configuration=config)
    _pcs.add(pc)

    @pc.on("connectionstatechange")
    async def on_state():
        log.info("PC state %s", pc.connectionState)
        if pc.connectionState in ("failed", "closed"):
            await pc.close()
            _pcs.discard(pc)

    pc.addTrack(LatestFrameTrack())
    await pc.setRemoteDescription(offer)
    answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)
    return web.json_response(
        {"sdp": pc.localDescription.sdp, "type": pc.localDescription.type}
    )


async def frame(request: web.Request) -> web.Response:
    """Ingest JPEG (or raw) frames — same contract as studio bridge /frame."""
    global _latest_jpeg, _latest_rgb
    data = await request.read()
    if not data:
        return web.json_response({"error": "empty"}, status=400)
    fmt = request.headers.get("X-Frame-Format", "jpeg").lower()
    if fmt in ("jpeg", "jpg"):
        _latest_jpeg = data
        _latest_rgb = None
    else:
        w = int(request.headers.get("X-Frame-Width", _width))
        h = int(request.headers.get("X-Frame-Height", _height))
        try:
            rgb = np.frombuffer(data, dtype=np.uint8).reshape((h, w, 3))
            _latest_rgb = rgb.copy()
            _latest_jpeg = None
        except Exception as e:
            return web.json_response({"error": str(e)}, status=400)
    return web.json_response({"ok": True, "bytes": len(data)})


async def health(request: web.Request) -> web.Response:
    return web.json_response(
        {
            "ok": True,
            "peers": len(_pcs),
            "hasFrame": _latest_jpeg is not None or _latest_rgb is not None,
            "width": _width,
            "height": _height,
            "fps": _fps,
            "latencyMode": "latest-frame-drop",
        }
    )


async def on_shutdown(app: web.Application) -> None:
    coros = [pc.close() for pc in _pcs]
    await asyncio.gather(*coros, return_exceptions=True)
    _pcs.clear()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()

    app = web.Application(client_max_size=8 * 1024 * 1024)
    app.router.add_get("/", index)
    app.router.add_get("/health", health)
    app.router.add_post("/offer", offer)
    app.router.add_post("/frame", frame)
    app.on_shutdown.append(on_shutdown)

    log.info("WebRTC low-latency server http://%s:%s", args.host, args.port)
    log.info("  Demo player: /  · SDP: POST /offer  · Frames: POST /frame")
    web.run_app(app, host=args.host, port=args.port, print=None)


if __name__ == "__main__":
    main()
