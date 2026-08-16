# Endless Cam / Studio — Cross-Platform Installation

Clear steps for **Windows, macOS, Linux, and Web**.  
Goal: endless virtual cam + studio features available to Zoom, Teams, Meet, Discord, and RTMP platforms.

---

## Shared prerequisites (all desktop OS)

1. **Flutter** 3.16+ — https://docs.flutter.dev/get-started/install  
2. **Python** 3.10+  
3. **FFmpeg** on PATH — https://ffmpeg.org/download.html  
4. This project folder: `endless_cam_studio`

Verify:

```bash
flutter --version
python3 --version
ffmpeg -version
```

---

## 1. Bridge (required on the machine that owns the camera)

```bash
cd endless_cam_studio/bridge
python3 -m venv .venv
```

| OS | Activate venv |
|----|----------------|
| Windows | `.venv\Scripts\activate` |
| macOS / Linux | `source .venv/bin/activate` |

```bash
pip install -r requirements.txt
python virtual_cam_bridge.py
```

Leave this terminal open. You should see bridge listening on `http://127.0.0.1:8766`.

Optional OBS control: open OBS → Tools → WebSocket Server → Enable (port **4455**).  
Password: set env `OBS_PASSWORD` before starting the bridge if OBS requires one.

---

## 2. App

```bash
cd endless_cam_studio
flutter pub get
```

| OS | Run |
|----|-----|
| **Windows** | `flutter run -d windows` |
| **macOS** | `flutter run -d macos` |
| **Linux** | `flutter run -d linux` |
| **Web UI** | `flutter run -d chrome` |

Web UI can control the **local** bridge; the system virtual camera still needs the desktop bridge process.

---

## 3. Virtual camera per OS (endless cam)

### Windows
- Bridge uses **pyvirtualcam** (or select **OBS Virtual Camera** if you use OBS).
- In Zoom / Teams / Discord / Meet: choose the virtual device as Camera.

### macOS
- Prefer **OBS Virtual Camera** (Start Virtual Camera in OBS), or pyvirtualcam where available.
- System Settings → Privacy & Security → Camera → allow Terminal, OBS, and the app.

### Linux (lowest latency path)
```bash
sudo apt update
sudo apt install v4l2loopback-dkms v4l-utils
sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="StudioCam" exclusive_caps=1
v4l2-ctl --list-devices   # confirm StudioCam /dev/video10
```
Then start FFmpeg vcam via bridge (`POST /vcam/ffmpeg/start` with `"lowLatency": true`) or use pyvirtualcam.  
Target added latency ~**40–120 ms** at 720p30.

---

## 4. Use in calls & social

| Use case | What to do |
|----------|------------|
| Zoom / Teams / Meet / Discord | Set camera = StudioCam / OBS Virtual Camera |
| Twitch / YouTube / TikTok / Facebook **live** | App → OBS Stream → platform chip → stream key → **GO LIVE** |
| TikTok / IG / Snap / WhatsApp / Telegram / FB **clips** | Video Edit → format chip → Export Shorts / Status |
| Film up to ~**2 hours** | Video Edit → YouTube/Film or Cinema → Export Feature |

---

## 5. Feature checklist (all enabled on endless cam path)

- [x] Real-time face swap → virtual cam / RTMP  
- [x] Still photo face swap  
- [x] Offline video face-swap render hook  
- [x] Beautify, auto light, background blur  
- [x] OBS scenes (WebSocket)  
- [x] RTMP streaming  
- [x] Short-form exports (TikTok, IG, Snap, WhatsApp, Telegram, Facebook)  
- [x] Long-form / cinema timeline (~2h class)  
- [x] AI chat easy + pro prompts  

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Bridge red / offline | Start `python virtual_cam_bridge.py`; check port 8766 |
| No virtual cam in Zoom | Restart app list; on Linux confirm `v4l2loopback`; on Mac grant camera privacy |
| RTMP fails | FFmpeg on PATH; valid stream key; firewall |
| OBS scenes demo only | Enable OBS WebSocket; matching password env |
| Flutter device missing | `flutter devices` — enable desktop/web: `flutter config --enable-windows-desktop` (or macos/linux) |

---

## One-page quick start

```text
1. Install Flutter + Python + FFmpeg
2. bridge: venv → pip install -r requirements.txt → python virtual_cam_bridge.py
3. app: flutter pub get → flutter run -d <windows|macos|linux|chrome>
4. Pick virtual cam in your call app  OR  Go Live with stream key
```

More product context: `PRODUCT_VISION.md` · pipeline: `ARCHITECTURE.md`
EOF

# Update README install pointer + duration story
cat > /home/workdir/artifacts/endless_cam_studio/README.md << 'EOF'
# Endless Cam / Studio v3.5

Endless virtual cam + studio for **Windows, macOS, Linux, Web**.

- **Calls:** Zoom, Teams, Meet, Discord, Slack… (as main camera)  
- **Live:** Twitch, YouTube, TikTok, Facebook (RTMP like OBS)  
- **Clips:** TikTok, Instagram, Snapchat, WhatsApp, Telegram, Facebook  
- **Films:** 16:9 / 21:9 timelines sized for about **up to 2 hours**  
- **Face:** real-time, still, or offline video · **AI chat** easy or pro  

## Install (all platforms)

**See [INSTALL.md](INSTALL.md)** for full Windows / macOS / Linux / Web steps.

```bash
# Bridge
cd bridge && python3 -m venv .venv && source .venv/bin/activate  # Win: .venv\Scripts\activate
pip install -r requirements.txt && python virtual_cam_bridge.py

# App
cd .. && flutter pub get && flutter run -d windows  # or macos | linux | chrome
```

Linux low-latency cam: v4l2loopback + FFmpeg (`INSTALL.md`).  
OBS scenes: enable WebSocket port 4455.

## Docs

| File | Contents |
|------|----------|
| **INSTALL.md** | Cross-platform install & troubleshooting |
| **PRODUCT_VISION.md** | Product scope & roadmap |
| **ARCHITECTURE.md** | Pipeline / RTMP / vcam |
EOF

# Patch PRODUCT_VISION duration section briefly
python3 << 'PY'
from pathlib import Path
p = Path('/home/workdir/artifacts/endless_cam_studio/PRODUCT_VISION.md')
t = p.read_text()
if 'up to 2 hours' not in t:
    t = t.replace(
        '| Edit | Shorts formats + AI prompts | Cinema timeline, grades, transitions |',
        '| Edit | Shorts (TikTok/IG/Snap/WA/TG/FB) + AI prompts | Cinema / YouTube up to ~2h, grades, transitions |',
    )
    p.write_text(t)
print('vision ok')
PY
echo DONE

## AI voice cloning (optional)

1. Run any local clone/TTS API that implements:
   - `GET /health`
   - `POST /clone` JSON `{ text, speakerId, ... }` → audio bytes
   - optional `GET /speakers`
2. Point the bridge at it:
   ```bash
   export VOICE_CLONE_URL=http://127.0.0.1:8777
   python virtual_cam_bridge.py
   ```
3. In the app open **Voice** → generate → add to timeline.

Examples of backends you can wire: OpenVoice, Coqui XTTS, RVC-based servers (your choice of model/license).

## 2-hour movie encode (bridge)

```bash
curl -X POST http://127.0.0.1:8766/export/movie \
  -H 'Content-Type: application/json' \
  -d '{
    "inputPath": "/path/to/timeline-master.mov",
    "outputPath": "/path/to/feature.mp4",
    "mode": "balanced",
    "codec": "libx264",
    "width": 1920,
    "height": 1080,
    "fps": 24,
    "audioKbps": 192
  }'
```

| mode | Use |
|------|-----|
| `fast` | Draft, veryfast CRF23 |
| `balanced` | Default feature delivery, medium CRF20 film-tune + faststart |
| `quality` | Final master, slow CRF18 |

NVENC: set `"codec": "h264_nvenc"` or `hevc_nvenc` if available.  
Status: `GET /export/status` · Cancel: `POST /export/cancel`

## Android

```bash
flutter create . --platforms=android   # if Gradle wrapper / icons missing
flutter pub get
flutter run -d android
# Release APK:
flutter build apk --release
```

Permissions already set: `CAMERA`, `RECORD_AUDIO`, `INTERNET`.  
Virtual cam into *other* Android apps is OS-limited; use **RTMP** or in-app preview on mobile. Desktop OS remain best for system-wide endless cam.
