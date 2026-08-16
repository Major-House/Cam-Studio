# Endless Cam / Studio — Detailed Linux Installation

Tested patterns: **Ubuntu 22.04 / 24.04**, **Debian 12**, **Fedora 39+**, **Arch**.  
Goal: real webcam → virtual camera (Zoom, Teams, Discord, browsers) + optional RTMP/NVENC live.

---

## 1. System packages

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y \
  python3 python3-venv python3-pip \
  ffmpeg v4l-utils \
  build-essential pkg-config \
  libgl1 libglib2.0-0

# Virtual camera kernel module
sudo apt install -y v4l2loopback-dkms v4l2loopback-utils

# Optional: Flutter desktop deps
sudo apt install -y clang cmake ninja-build libgtk-3-dev
```

### Fedora

```bash
sudo dnf install -y python3 python3-pip ffmpeg v4l-utils \
  gcc gcc-c++ pkg-config \
  v4l2loopback  # or v4l2loopback from RPM Fusion if needed
sudo dnf install -y clang cmake ninja-build gtk3-devel
```

### Arch

```bash
sudo pacman -S python python-pip ffmpeg v4l-utils base-devel
yay -S v4l2loopback-dkms   # or pacman if in repos
sudo pacman -S clang cmake ninja gtk3
```

### Verify core tools

```bash
python3 --version    # 3.10+
ffmpeg -version      # must be on PATH
v4l2-ctl --version
```

---

## 2. Load the virtual camera (v4l2loopback)

```bash
# Load module (video_nr=10 → /dev/video10)
sudo modprobe v4l2loopback \
  devices=1 \
  video_nr=10 \
  card_label="EndlessCam" \
  exclusive_caps=1

# Confirm
v4l2-ctl --list-devices
ls -l /dev/video10
```

You should see **EndlessCam** (or similar) and `/dev/video10`.

### Persist across reboots

```bash
echo "v4l2loopback" | sudo tee /etc/modules-load.d/v4l2loopback.conf

echo 'options v4l2loopback devices=1 video_nr=10 card_label="EndlessCam" exclusive_caps=1' \
  | sudo tee /etc/modprobe.d/v4l2loopback.conf

# Rebuild initramfs if your distro requires it (Debian/Ubuntu often optional for this module)
# sudo update-initramfs -u
```

### Permission tip

If user cannot open `/dev/video10`:

```bash
# Usually video group owns V4L devices
sudo usermod -aG video "$USER"
# Log out and back in
```

---

## 3. Python engine (real endless cam)

```bash
cd endless_cam_studio/bridge
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
# Core for engine:
pip install opencv-python-headless numpy pyvirtualcam flask pillow
```

### Run virtual cam only

```bash
source .venv/bin/activate
python endless_engine.py \
  --camera 0 \
  --width 1280 \
  --height 720 \
  --fps 30 \
  --device /dev/video10
```

Or without `--device` if pyvirtualcam finds the loopback automatically.

### Run with RTMP (Twitch / YouTube)

```bash
python endless_engine.py \
  --camera 0 \
  --rtmp "rtmp://live.twitch.tv/app/YOUR_STREAM_KEY" \
  --bitrate 4500
```

### NVIDIA NVENC (if you have an NVIDIA GPU)

```bash
# Drivers + CUDA toolkit per NVIDIA docs for your distro
ffmpeg -hide_banner -encoders 2>/dev/null | grep nvenc

python endless_engine.py \
  --rtmp "rtmp://…" \
  --nvenc \
  --bitrate 4500
```

### Local preview window

```bash
python endless_engine.py --preview
# Press Q to quit
```

---

## 4. Use in call apps (Linux)

| App | How to select EndlessCam |
|-----|---------------------------|
| **Zoom** | Settings → Video → Camera → EndlessCam |
| **Teams** | Devices → Camera |
| **Discord** | User Settings → Voice & Video → Camera |
| **Chrome Meet** | Settings → Video → select device (must see V4L2 device) |
| **OBS** | Sources → Video Capture Device → EndlessCam; or Start Virtual Camera after using Endless as source |

If the device does not appear: restart the app after `modprobe`, confirm `v4l2-ctl --list-devices`, ensure engine is running.

---

## 5. Optional: HTTP bridge + WHIP + WebRTC

```bash
source .venv/bin/activate
python virtual_cam_bridge.py          # :8766  RTMP API / OBS WebSocket proxy
python webrtc_server.py               # :8787  browser preview
export WHIP_TOKEN=secret123
python whip_server.py                 # :8788  WHIP ingest RFC 9725
```

OBS WebSocket: OBS → Tools → WebSocket Server → Enable (port **4455**).

---

## 6. Optional: Flutter control UI (Linux desktop)

```bash
# Install Flutter: https://docs.flutter.dev/get-started/install/linux
flutter config --enable-linux-desktop
cd endless_cam_studio
flutter create . --project-name endless_cam_studio --platforms=linux
flutter pub get
flutter run -d linux
```

UI is the control surface; **video path** is still `endless_engine.py`.

---

## 7. Camera index & troubleshooting

```bash
# List capture devices
v4l2-ctl --list-devices
ls -l /dev/video*

# Test webcam
ffplay -f v4l2 -i /dev/video0
# or
python -c "import cv2; c=cv2.VideoCapture(0); print(c.isOpened()); c.release()"
```

| Problem | Fix |
|---------|-----|
| `modprobe: module v4l2loopback not found` | Install `v4l2loopback-dkms`, reboot, or install headers: `linux-headers-$(uname -r)` |
| No `/dev/video10` | `sudo modprobe v4l2loopback …` again; check `dmesg \| tail` |
| Zoom doesn’t list cam | Start engine first; restart Zoom; try OBS Virtual Cam as middle layer |
| `pyvirtualcam` fails | Rely on FFmpeg→v4l2 path via bridge, or fix loopback flags (`exclusive_caps=1`) |
| Permission denied | Add user to `video` group; re-login |
| High latency | Use 720p30; NVENC if available; see `bridge/STREAMING_LATENCY.md` |
| Wayland + some apps | Prefer X11 session if virtual cam not listed under Wayland |

---

## 8. Minimal “world ready” checklist (Linux)

```text
[ ] apt/dnf packages: python3, ffmpeg, v4l2loopback-dkms
[ ] modprobe v4l2loopback → /dev/video10 EndlessCam
[ ] venv + pip install -r requirements.txt
[ ] python endless_engine.py --camera 0
[ ] Zoom/Teams shows EndlessCam and live picture
[ ] Optional: --rtmp + --nvenc for public live
```

You are live on Linux when another app sees **EndlessCam** and shows your processed feed in real time.
EOF

# Point INSTALL.md at the detailed guide
python3 << 'PY'
from pathlib import Path
p = Path('/home/workdir/artifacts/endless_cam_studio/INSTALL.md')
t = p.read_text()
if 'INSTALL_LINUX.md' not in t:
    t = t.replace(
        '### Linux (lowest latency path)',
        '### Linux (lowest latency path)\n\n**Full guide:** [INSTALL_LINUX.md](INSTALL_LINUX.md) (packages, v4l2loopback persist, NVENC, troubleshooting).\n\n### Linux (lowest latency path) — short',
        1
    )
    p.write_text(t)
    print('INSTALL.md linked')
else:
    print('already linked')
PY

# Refresh zip
cd /home/workdir/artifacts && zip -qr Endless_Cam_Studio_WORLD_READY.zip endless_cam_studio/INSTALL_LINUX.md && ls -lh Endless_Cam_Studio_WORLD_READY.zip
