# NVENC + WebRTC — low-latency delivery

## 1. NVIDIA NVENC (hardware encode)

### Auto-detect
```bash
curl -s http://127.0.0.1:8766/encode/capabilities | python3 -m json.tool
```
When `nvenc_h264: true`, the recommended codec is `h264_nvenc`.

### RTMP / live
`POST /rtmp/start` body:
```json
{
  "publishUrl": "rtmp://…/live/…",
  "videoCodec": "h264_nvenc",
  "nvencPreset": "p1",
  "lowLatency": true,
  "width": 1280,
  "height": 720,
  "fps": 30,
  "videoBitrateKbps": 4500
}
```
| Field | Meaning |
|-------|---------|
| `videoCodec` | `h264_nvenc`, `hevc_nvenc`, `auto`, or `libx264` |
| `nvencPreset` | `p1` = lowest latency · `p4` = balanced quality |
| `lowLatency` | Prefer `p1` when true |

Encode path uses **CBR, no B-frames, short GOP, zerolatency-style delay flags**, no `-re` on input (avoids forced clock lag).

FFmpeg must be built with NVENC (official NVIDIA builds or distro packages that enable it). Drivers: recent NVIDIA Game Ready / Studio.

### Movie export
`POST /export/movie` already accepts `"codec": "h264_nvenc"` / `hevc_nvenc`.

### App default
Flutter live start now sends `videoCodec: auto` so the bridge picks NVENC when present.

---

## 2. WebRTC (lowest practical latency to a browser)

RTMP is for platforms (Twitch/YouTube). **WebRTC** is for:

- Ultra-low-latency preview in a browser  
- Custom web viewers / control rooms  
- Sub-second glass-to-glass on LAN  

### Run
```bash
cd bridge
pip install aiortc av aiohttp
python webrtc_server.py
# http://127.0.0.1:8787/  → Connect
```

| Endpoint | Role |
|----------|------|
| `GET /` | Demo player |
| `POST /offer` | SDP answer |
| `POST /frame` | JPEG/raw frames (same idea as bridge `/frame`) |
| `GET /health` | Peers + frame status |

### Latency design
- **Latest-frame wins** — no queue of old frames  
- UDP ICE (STUN by default)  
- Tuned for **30 fps** @ 1280×720 (env: `WEBRTC_WIDTH`, `WEBRTC_HEIGHT`, `WEBRTC_FPS`)  
- Bundle + RTCP mux  

Typical **LAN browser** latency: often **~100–400 ms** depending on capture and encode of the *source* frames (WebRTC itself is not the bottleneck).

### Wiring from studio
1. Process frames as usual.  
2. Also `POST` JPEG to `http://127.0.0.1:8787/frame`.  
3. Viewers open the demo page or run their own `RTCPeerConnection` against `/offer`.

Optional: bridge can later fan-out `/frame` to WebRTC automatically.

### WebRTC vs RTMP vs virtual cam

| Path | Best for | Latency class |
|------|----------|----------------|
| **Virtual cam** | Zoom, Teams, Discord | Lowest for native apps |
| **WebRTC** | Browser / custom web | Lowest for web |
| **RTMP + NVENC** | Twitch, YouTube, FB | Platform CDN dominates (seconds) |

---

## 3. Recommended “world-ready” stack

```text
Camera → Studio pipeline (face / grade)
              ├─→ Virtual cam          → call apps
              ├─→ WebRTC :8787         → browser preview / web viewers
              └─→ RTMP + NVENC :8766   → Twitch / YouTube / TikTok live
```

1. Start `virtual_cam_bridge.py`  
2. Start `webrtc_server.py` (optional web path)  
3. `flutter run`  
4. Confirm `GET /encode/capabilities` shows NVENC when on NVIDIA  

You are ready for local calls, web preview, and public live with hardware encode where available.
EOF

# Point STREAMING_LATENCY at new doc
echo "
## See also
- WEBRTC_AND_NVENC.md — NVENC presets + WebRTC server
" >> /home/workdir/artifacts/hollywood_studio_pro/bridge/STREAMING_LATENCY.md

echo OK
python3 -c "import ast; ast.parse(open('/home/workdir/artifacts/hollywood_studio_pro/bridge/virtual_cam_bridge.py').read()); print('bridge ok')"
python3 -c "import ast; ast.parse(open('/home/workdir/artifacts/hollywood_studio_pro/bridge/webrtc_server.py').read()); print('webrtc ok')"
