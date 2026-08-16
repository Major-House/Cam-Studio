# Endless Cam / Studio — Real Endless Virtual Cam Architecture

## Goal

Continuous (endless) virtual camera that any app can use:

```
Webcam ──► Flutter capture ──► Processors (swap / beautify / BG / grade)
                                      │
                                      ▼
                              Frame sinks
                           ┌──────┴──────┐
                           │             │
                     In-app preview   HTTP/WS bridge
                                           │
                                           ▼
                                  Python virtual-cam bridge
                                           │
                                           ▼
                                  System Virtual Webcam
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    ▼                      ▼                      ▼
                  Zoom                  Teams                    OBS / Twitch
```

## What was missing (and is now in the project)

| Missing piece | Status |
|---------------|--------|
| Real camera capture | `lib/core/camera_source.dart` + `camera` package |
| Frame pipeline (source → processors → sinks) | `lib/core/pipeline.dart` |
| Face-swap / beautify / BG processors | `lib/core/processors.dart` (hooks + external service) |
| Preview + HTTP/WS sinks | `lib/core/sinks.dart` |
| System virtual webcam | `bridge/virtual_cam_bridge.py` (pyvirtualcam) |
| Dependencies | Updated `pubspec.yaml` |
| Permissions / platform notes | This document |

## Run the real loop (desktop)

### 1. Start the virtual-cam bridge

```bash
cd bridge
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python virtual_cam_bridge.py
```

You should see: `Virtual cam started: ...`

### 2. Run the Flutter app

```bash
flutter pub get
flutter run -d windows   # or macos / linux / chrome
```

### 3. In the app

1. Open **Capture** or **Face Swap**.
2. Grant camera permission.
3. Start pipeline / Activate Face Swap / Go Live.
4. Frames are pushed to `http://127.0.0.1:8766/frame`.

### 4. Use the virtual camera

In Zoom / Teams / Google Meet / OBS:

- Choose the camera named by pyvirtualcam (often “OBS Virtual Camera” style or “Unity Video Capture” / device name printed in the bridge log).

The feed stays alive even if Flutter briefly pauses (bridge idle loop re-sends the last frame).

## Face swap (real model)

`ExternalFaceSwapProcessor` is the integration point.

Recommended local service:

1. Run [FaceFusion](https://github.com/facefusion/facefusion) or an InsightFace demo server on `127.0.0.1:8765`.
2. Set `endpoint` + `targetFaceId` on the processor.
3. Enable the processor in the pipeline.

Until that service is running, the processor is a no-op so the rest of the pipeline still works.

## Platform notes

- **Windows**: `camera_windows` + pyvirtualcam works well.
- **macOS**: camera works; virtual cam may need OBS Virtual Camera or a signed driver.
- **Linux**: v4l2loopback + pyvirtualcam is the usual path.
- **Mobile**: virtual camera into other apps is restricted; use in-app preview + RTMP out instead.
- **Web**: no system virtual cam; use WebRTC or RTMP.

## Security

- Bridge binds to `127.0.0.1` only.
- Never expose stream keys or the bridge to the public internet.
- Store secrets outside the repo.

## Next engineering steps

1. Wire `StudioState.toggleStream()` to `StudioPipeline.start/stop`.
2. Show `PreviewSink` frames in the right-panel preview.
3. Add a real InsightFace / FaceFusion microservice and point `ExternalFaceSwapProcessor` at it.
4. Optional: OBS WebSocket control for scene switching from the Flutter UI.

## RTMP live streaming

```
App (OBS Stream → GO LIVE)
    │  POST /rtmp/start  { rtmpUrl, streamKey, bitrate, … }
    ▼
Bridge (virtual_cam_bridge.py)
    │  spawns ffmpeg -f mjpeg -i pipe:0 … -f flv rtmp://…
    │
    │  POST /rtmp/frame  (JPEG frames from pipeline)
    ▼
Twitch / YouTube / Facebook / custom RTMP ingest
```

### Start

1. `python bridge/virtual_cam_bridge.py` (ffmpeg on PATH)
2. Flutter app → OBS Stream → enter ingest URL + stream key → **GO LIVE**
3. Optional: run camera pipeline so `/rtmp/frame` gets real frames; otherwise FFmpeg may wait for input

### Twitch example

- URL: `rtmp://live.twitch.tv/app/`
- Key: from Twitch dashboard (live_…)

### YouTube example

- URL: `rtmp://a.rtmp.youtube.com/live2/`
- Key: from YouTube Studio stream settings

### API (bridge)

| Method | Path | Body |
|--------|------|------|
| POST | `/rtmp/start` | JSON config |
| POST | `/rtmp/frame` | raw JPEG + headers |
| POST | `/rtmp/stop` | — |
| GET | `/rtmp/stats` | — |
