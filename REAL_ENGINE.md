# Endless Cam / Studio — REAL engine (not a demo)

The Flutter UI is a **control surface**. The **real camera path** is this Python engine.

## What is actually real

| Component | Status |
|-----------|--------|
| `bridge/endless_engine.py` | **Real** webcam capture → virtual cam + RTMP |
| `bridge/virtual_cam_bridge.py` | **Real** HTTP API for FFmpeg RTMP, OBS WebSocket, frames |
| `bridge/webrtc_server.py` | **Real** WebRTC when `aiortc` is installed |
| Face swap ML | **Hook only** — plug InsightFace / FaceFusion yourself |
| AI chat replies | **Guided text** — not a cloud LLM unless you wire one |
| Timeline / export UI | **UI + FFmpeg `/export/movie`** when you pass real files |

## Run the real endless camera (desktop)

```bash
cd endless_cam_studio/bridge
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install opencv-python-headless numpy pyvirtualcam flask pillow
# FFmpeg must be on PATH
```

### Virtual cam only (Zoom / Teams / Discord)

```bash
python endless_engine.py --camera 0 --width 1280 --height 720 --fps 30
```

Then in Zoom/Teams: select the **virtual camera device** as Camera.

**Linux** (if needed first):

```bash
sudo apt install v4l2loopback-dkms
sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="EndlessCam" exclusive_caps=1
python endless_engine.py --device /dev/video10
```

### RTMP live (Twitch / YouTube) + optional NVENC

```bash
python endless_engine.py \
  --rtmp "rtmp://live.twitch.tv/app/YOUR_STREAM_KEY" \
  --nvenc \
  --bitrate 4500
```

### Local preview window

```bash
python endless_engine.py --preview
```

## Verify it is working

1. Engine log shows `Virtual camera ON → …`
2. Zoom/Teams camera list includes that device
3. You see the red **ENDLESS CAM** badge and clock on the feed
4. With `--rtmp`, dashboard shows you live

If virtual cam fails, the log tells you exactly what to install — it does not silently “demo.”

## Flutter app role

Use the app for keys, platform presets, OBS scenes, and delivery path reminders.  
**Glass-to-glass video** for calls/streams comes from **`endless_engine.py`** (or the bridge + FFmpeg), not from animated UI panels.

## Face swap (real, optional)

Point a separate process (FaceFusion, InsightFace, Deep-Live-Cam, etc.) at the same camera and feed **its** output into a virtual cam, or composite into this engine later. The product leaves that as an explicit integration so we never fake ML quality.
EOF
