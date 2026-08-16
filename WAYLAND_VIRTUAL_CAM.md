# Wayland + virtual camera (Endless Cam / Studio)

Linux under **Wayland** does not break v4l2loopback itself. Problems usually come from:

1. Apps that only speak **PipeWire** / portal cameras  
2. Missing **`exclusive_caps=1`** (Chrome, Zoom, WebRTC)  
3. Confusing **screen capture** (X11 grab is black on Wayland) with **webcam loopback**

Endless Cam feeds a **V4L2 loopback device** from your real webcam — that path works on Wayland for many apps when set up correctly.

---

## 1. Recommended: v4l2loopback + exclusive_caps

```bash
sudo modprobe -r v4l2loopback 2>/dev/null

sudo modprobe v4l2loopback \
  devices=1 \
  video_nr=10 \
  card_label="EndlessCam" \
  exclusive_caps=1

v4l2-ctl --list-devices
# Expect: EndlessCam → /dev/video10
```

`exclusive_caps=1` is important for **Chromium / Zoom / WebRTC** so the device is listed as a pure capture device after a producer attaches.  

Then:

```bash
cd bridge && source .venv/bin/activate
python endless_engine.py --camera 0 --device /dev/video10 --width 1280 --height 720 --fps 30
```

Select **EndlessCam** in Zoom, Teams, Discord, or browser settings.

### Check session type

```bash
echo $XDG_SESSION_TYPE
# wayland  or  x11
```

---

## 2. App behavior on Wayland

| App | Typical path |
|-----|----------------|
| **Zoom** (native .deb) | Often sees V4L2 loopback with `exclusive_caps=1` |
| **Discord** | Usually lists V4L2 devices |
| **Firefox** | PipeWire + portals; may also show V4L2 depending on build |
| **Chrome / Chromium / Meet** | Prefer devices that look like real webcams; `exclusive_caps=1` helps |
| **Flatpak Zoom/Chrome** | Sandbox may hide `/dev/video*`; grant device permission or use non-Flatpak build |
| **OBS** | Capture V4L2 source → **Start Virtual Camera** (OBS’s own VC helps some apps) |

**Flatpak device access example:**

```bash
# Inspect
flatpak info --show-permissions us.zoom.Zoom
# May need --device=all when installing/running, or Flatseal to allow video devices
```

---

## 3. PipeWire as an alternative virtual source

PipeWire can publish a **Video/Source** node without v4l2loopback. PipeWire-aware apps (many browsers via portal) can use it; classic V4L2-only apps may not.

Example (test pattern → PipeWire camera-like source):

```bash
sudo apt install gstreamer1.0-tools gstreamer1.0-pipewire   # Debian/Ubuntu

gst-launch-1.0 videotestsrc ! video/x-raw,format=YUY2 ! \
  pipewiresink mode=provide \
  stream-properties="properties,media.class=Video/Source,media.role=Camera" \
  client-name="EndlessCamPW"
```

For a real pipeline, replace `videotestsrc` with your processed frames (custom app or GStreamer appsrc). This is the direction “PipeWire is the new v4l2loopback” discussions point to for desktop integration.

---

## 4. OBS middle layer (most reliable)

Often the most compatible stack on Wayland:

```text
Webcam → endless_engine.py → /dev/video10
         → OBS “Video Capture Device” (EndlessCam)
         → OBS “Start Virtual Camera”
         → Zoom / Teams / browser pick “OBS Virtual Camera”
```

OBS handles some app quirks better than raw loopback alone.

---

## 5. When to switch to X11

If an app **never** lists the virtual camera under Wayland:

**GNOME (gdm):**

```bash
# /etc/gdm3/custom.conf  (or /etc/gdm/custom.conf)
WaylandEnable=false
```

Log out → log in → confirm:

```bash
echo $XDG_SESSION_TYPE   # should be x11
```

Then reload v4l2loopback and restart the engine.

---

## 6. What does *not* work on Wayland

| Technique | Wayland result |
|-----------|----------------|
| `ffmpeg -f x11grab` for **desktop** → loopback | Often **black** (no full-desktop X capture) |
| Assuming every Flatpak sees `/dev/video10` | Often **blocked** without permissions |
| Screen share protocols for **fake webcam** | Different API (portal); not the same as Endless Cam’s webcam loopback |

Endless Cam’s job is **camera replacement**, not screen-as-camera. Screen-as-camera needs portal/PipeWire/wf-recorder-style tools.

---

## 7. Quick diagnostic

```bash
echo "Session: $XDG_SESSION_TYPE"
ls -l /dev/video*
v4l2-ctl --list-devices

# Is anything writing to the loopback?
fuser -v /dev/video10 2>&1

# View loopback (while engine runs)
ffplay -f v4l2 -i /dev/video10
```

If `ffplay` shows your face but Zoom does not → app selection / sandbox / restart app.  
If `ffplay` is black → engine not writing or wrong device index.

---

## 8. Endless Cam defaults for Wayland

1. Always use **`exclusive_caps=1`**  
2. Prefer **native** (non-Flatpak) Zoom/Discord when possible  
3. Use **OBS Virtual Camera** as fallback  
4. Keep **720p30** for lower CPU latency  
5. Document X11 fallback only if a required app fails  

See also: `INSTALL_LINUX.md` · `REAL_ENGINE.md`
EOF

# Link from INSTALL_LINUX.md
python3 << 'PY'
from pathlib import Path
p = Path('/home/workdir/artifacts/endless_cam_studio/INSTALL_LINUX.md')
t = p.read_text()
if 'WAYLAND_VIRTUAL_CAM.md' not in t:
    t = t.replace(
        '| Wayland + some apps | Prefer X11 session if virtual cam not listed under Wayland |',
        '| Wayland + some apps | See **[WAYLAND_VIRTUAL_CAM.md](WAYLAND_VIRTUAL_CAM.md)** (exclusive_caps, PipeWire, OBS, X11 fallback) |',
    )
    p.write_text(t)
    print('linked')
PY
echo ok
