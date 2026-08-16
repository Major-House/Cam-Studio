# Endless Cam / Studio

![Endless Cam / Studio](assets/branding/endless_cam_studio_logo.jpg)


> **Real camera path:** `python bridge/endless_engine.py` → virtual cam + optional RTMP. Full truth: [REAL_ENGINE.md](REAL_ENGINE.md).


**Endless virtual camera + Hollywood-grade studio for every OS.**

One pipeline. Three ways the world sees you:

| # | Path | Best for |
|---|------|----------|
| **1** | **Virtual Cam** | Zoom, Teams, Meet, Discord, Slack |
| **2** | **WebRTC** | Browser preview · ultra-low latency (`:8787`) |
| **3** | **RTMP + NVENC** | Twitch, YouTube, TikTok, Facebook live |

Also: real-time / still face swap · AI voice (Coqui XTTS) · shorts + ~2h film export · OBS scenes · AI chat (easy & pro).

---

## All OS — quick start

**Need:** Flutter 3.16+, Python 3.10+, FFmpeg on PATH.

```bash
# 1) Bridge (camera / RTMP / OBS)
cd bridge
python3 -m venv .venv
# Windows: .venv\Scripts\activate
source .venv/bin/activate
pip install -r requirements.txt
python virtual_cam_bridge.py

# 2) App
cd ..
flutter pub get
flutter run -d windows    # or: macos | linux | chrome
```

Optional WebRTC browser path:
```bash
pip install aiortc av aiohttp
python bridge/webrtc_server.py
# open http://127.0.0.1:8787
```

Full install matrix: **[INSTALL.md](INSTALL.md)**  
NVENC + WebRTC: **[bridge/WEBRTC_AND_NVENC.md](bridge/WEBRTC_AND_NVENC.md)**  
Product scope: **[PRODUCT_VISION.md](PRODUCT_VISION.md)**

---

## Remember the 3 delivery paths

1. **Virtual Cam** — pick StudioCam / OBS Virtual Camera in any call app  
2. **WebRTC** — browser at `:8787`  
3. **RTMP + NVENC** — OBS Stream tab → platform → key → Go Live (`videoCodec: auto`)

Linux low-latency cam: `v4l2loopback` → see INSTALL.md.

---

## License & privacy

Bridge binds to `127.0.0.1`. Stream keys stay local. Face/voice models are your responsibility (check Coqui/XTTS terms for commercial use).

---

*Endless Cam / Studio — from first call to final cut, on Windows, macOS, Linux, and Web.*

## Platforms in this repo

| Folder | OS |
|--------|-----|
| `android/` | **Android** (phone/tablet) |
| `ios/` | iOS |
| `windows/` | Windows desktop |
| `macos/` | macOS desktop |
| `linux/` | Linux desktop |
| `web/` | Chrome / Edge / Firefox |

After clone, regenerate complete native runners (icons, Gradle wrapper, full CMake) with:

```bash
flutter create . --project-name endless_cam_studio \
  --org com.endlesscam \
  --platforms=android,ios,web,windows,macos,linux
```

This keeps your `lib/` and `bridge/` and fills any missing native files.

### Android run

```bash
flutter config --enable-android
flutter devices
flutter run -d android
# or: flutter build apk
```

Camera + internet permissions are declared in `android/app/src/main/AndroidManifest.xml`.