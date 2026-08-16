# Endless Cam / Studio — Product Vision (Cross-Platform Endless Cam)

**One studio. Every OS. Every call app. Live or still. Pro or easy.**

---

## What you get

A continuous **virtual camera + studio control surface** so Zoom, Teams, Meet, Discord, Slack, browsers, and OBS all see the same polished feed:

| Capability | Amateur (Easy) | Professional |
|------------|----------------|--------------|
| Face swap | One-tap real-time or still | Blend, scale, mesh, external model |
| Virtual cam | Endless system camera | FFmpeg v4l2 / pyvirtualcam / OBS VC |
| Streaming | Platform chip + stream key → Go Live | RTMP multi-destination, bitrate, codec |
| OBS | Scene chips from the app | WebSocket scenes, studio mode |
| Edit | Shorts formats + AI prompts | Cinema timeline, grades, transitions |
| Assist | Natural-language AI chat | Advanced prompts + workflow tips |

---

## Endless cam — how every app sees you

```
Camera / swap / grade
        ↓
   Studio Pipeline
        ↓
 ┌──────┴──────┐
 │             │
Virtual Cam   RTMP
 │             │
Zoom/Teams    Twitch/YouTube
Meet/Discord  Custom ingest
Browser       OBS as encoder
```

- **As main camera:** OS virtual device (pyvirtualcam or FFmpeg→v4l2loopback). Pick “StudioCam” / OBS Virtual Camera in any app.
- **As stream:** RTMP out like OBS — Twitch, YouTube, Facebook, TikTok, custom.
- **As OBS source:** App feeds virtual cam; OBS adds scenes, overlays, recording.

Feed never dies: bridge re-sends the last frame so the device stays alive.

---

## OS readiness

| OS | Virtual cam path | Notes |
|----|------------------|--------|
| **Windows** | pyvirtualcam / OBS Virtual Camera | Select device in Zoom, Teams, Discord |
| **macOS** | OBS Virtual Camera (recommended) | Privacy → Camera permissions |
| **Linux** | **v4l2loopback + FFmpeg low-latency** or pyvirtualcam | `modprobe v4l2loopback … video_nr=10` |
| **Web (Chrome)** | UI + localhost bridge | Controls studio; system cam needs desktop bridge |
| **Mobile** | Preview + RTMP | OS limits virtual cam into other apps |

### Linux v4l2loopback (low latency)

```bash
sudo apt install v4l2loopback-dkms
sudo modprobe v4l2loopback devices=1 video_nr=10 \
  card_label="StudioCam" exclusive_caps=1

# Bridge low-latency path
curl -X POST http://127.0.0.1:8766/vcam/ffmpeg/start \
  -H 'Content-Type: application/json' \
  -d '{"device":"/dev/video10","width":1280,"height":720,"fps":30,"lowLatency":true}'
```

**Latency target:** about **40–120 ms** extra at 720p30 with `nobuffer`, `low_delay`, unbuffered pipe, MJPEG quality ~80. Prefer 720p over 1080p for calls; use 1080p for stage/stream.

### OBS WebSocket (optimized)

- Host/port/password from env: `OBS_HOST`, `OBS_PORT`, `OBS_PASSWORD`
- 2s timeouts, client reuse 30s, auto-reconnect on failure
- Scene switch returns `rttMs`
- Enable in OBS: Tools → WebSocket Server Settings

---

## Feature map

1. **Face switch** — Real-time live cam, still photo export, or offline video render.  
2. **Hollywood edit** — Shorts 9:16, film 16:9, grades, transitions, AI Auto-Cut, dual export.  
3. **OBS-class live** — Sources, scenes, RTMP, multi-platform presets, bridge health.  
4. **AI chat** — Easy-mode natural language (“go live on Twitch”, “start face swap”).  
5. **API Hub** — Twitch, YouTube, Zoom, Teams, Discord, NDI, webhooks (connect toggles).

---

## Quick start (all desktop OS)

```bash
# 1. Bridge
cd bridge && python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python virtual_cam_bridge.py

# 2. App
cd .. && flutter pub get
flutter run -d windows    # or macos / linux / chrome
```

1. Open **OBS Stream** → platform chip → paste key → **GO LIVE NOW**  
2. Or enable virtual cam and select it in Zoom/Teams as the camera  
3. **Face Swap** → Real-time → Start → Send to OBS / Live  
4. **Video Edit** for shorts/film; **AI Chat** for guided steps  

---

## Future roadmap (refined)

| Horizon | Focus |
|---------|--------|
| **Now** | UI + bridge (virtual cam, RTMP, OBS scenes, edit surfaces) |
| **Next** | Ship default InsightFace/FaceFusion microservice; one-click model download |
| **Then** | Signed macOS virtual cam; Windows driver installer; mobile RTMP templates |
| **Later** | Cloud relay for multi-person swap; marketplace LUTs/faces; NDI out |

**Success metric:** Any user on Windows, Mac, or Linux can open a video call or go live with a swapped face or graded studio look in under five minutes after installing Flutter deps, FFmpeg, and the bridge.

---

## Safety & privacy

- Bridge binds to **127.0.0.1** only  
- Stream keys stay on device; never commit secrets  
- Face models and captures are local unless the user points at a remote API  

---

*Endless Cam / Studio — endless cam for every platform, from first stream to final cut.*
EOF

# Sync README to point at vision
cat > /home/workdir/artifacts/endless_cam_studio/README.md << 'EOF'
# Endless Cam / Studio v3.4

Endless virtual cam + OBS-style studio for **Windows, macOS, Linux, and Web**.

Works as:
- **Main camera** in Zoom, Teams, Meet, Discord, Slack, browsers  
- **RTMP stream** to Twitch, YouTube, TikTok, Facebook (OBS-like)  
- **OBS companion** — scene switching over optimized WebSocket  

Includes real-time / still face swap, cinema & shorts editor, and AI chat (easy or pro).

## Start in 2 terminals

```bash
# Terminal 1 — bridge (virtual cam + RTMP + OBS)
cd bridge && pip install -r requirements.txt && python virtual_cam_bridge.py

# Terminal 2 — app
flutter pub get && flutter run -d windows   # macos | linux | chrome
```

## Low-latency Linux camera (v4l2)

```bash
sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="StudioCam" exclusive_caps=1
# App/bridge: POST /vcam/ffmpeg/start with lowLatency: true
```

Target added latency: **~40–120 ms** at 720p30.

## Docs

- **PRODUCT_VISION.md** — full cross-platform product summary & roadmap  
- **ARCHITECTURE.md** — pipeline & RTMP diagram  

## OBS WebSocket

Enable in OBS (port 4455). Optional: `OBS_PASSWORD`, `OBS_HOST`, `OBS_PORT`.  
Bridge auto-reconnects and reports scene-switch RTT.
EOF

echo OK
ls -la /home/workdir/artifacts/endless_cam_studio/*.md /home/workdir/artifacts/endless_cam_studio/bridge/
