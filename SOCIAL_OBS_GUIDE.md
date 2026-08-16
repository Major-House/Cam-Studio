# Endless Cam / Studio — OBS + every social / call app

## Pro setup (OBS manual)

1. Install **OBS Studio** + enable **Virtual Camera**  
2. Install **obs-websocket** (built-in on OBS 28+: Tools → WebSocket Server → Enable, port **4455**)  
3. Run the real engine:
   ```bash
   python bridge/endless_engine.py --camera 0 --width 1280 --height 720 --fps 30
   ```
4. In OBS: **Sources → Video Capture Device** → select **EndlessCam / OBS Virtual Camera / StudioCam**  
5. Optional: filter → Face swap app as intermediate device if you use Deep-Live-Cam / FaceFusion  
6. **Start Virtual Camera** in OBS (so Zoom etc. see OBS output with overlays)  
7. For public live: OBS → Settings → Stream → service, **or** engine `--rtmp URL --nvenc`

### OBS settings (low latency / calls)

| Setting | Value |
|---------|--------|
| Canvas | 1280×720 (calls) or 1920×1080 (stage) |
| FPS | 30 |
| Output → Advanced → Rate Control | CBR |
| Bitrate | 2500–4500 (calls/stream) |
| Keyframe | 2 s |
| Encoder | **NVENC** if available (lowest CPU) |
| WebSocket | On, port 4455 |

### Face swap modes

| Mode | How |
|------|-----|
| **Real-time** | Run face-swap tool → output virtual cam → OBS or Zoom picks that cam |
| **Still image** | Face Swap tab / tool → export photo → use as avatar or post |

---

## Video calls — pick **Virtual Cam** as camera

After `endless_engine.py` (or OBS Virtual Cam) is running:

| App | Where to select camera |
|-----|-------------------------|
| **Zoom** | Settings → Video → Camera → EndlessCam / OBS Virtual Camera |
| **Microsoft Teams** | Devices → Camera → same device |
| **Google Meet** | Settings (gear) → Video → select virtual cam (Chrome; OS must expose device) |
| **Discord** | User Settings → Voice & Video → Camera |
| **Skype** | Settings → Audio & Video → Camera |
| **Webex** | Settings → Video → Camera |
| **Signal** | Desktop: call → cycle camera / OS default; prefer OBS VC on desktop |
| **Slack** | Huddle → camera device in settings |
| **WhatsApp Desktop** | Call → camera selection depends on OS; Windows/mac often list virtual cams |
| **Telegram Desktop** | Settings → Privacy → or in-call camera device list |

**Mobile (WhatsApp / Telegram / Signal / Snapchat apps):** OS usually **blocks** third-party virtual cameras. Use **desktop** apps or **RTMP/web** for processed video; still-image swap → export → post as photo/story.

---

## Social posting & live (pros)

| Platform | Real-time / live | Still face swap |
|----------|------------------|-----------------|
| **Twitch** | RTMP + NVENC or OBS Stream | — |
| **YouTube Live** | RTMP / OBS | — |
| **TikTok Live** | RTMP (region-dependent) or OBS | Export vertical still/clip |
| **Facebook / IG Live** | RTMP or OBS | Still → Feed / Story |
| **Snapchat** | Mobile camera only for AR; desktop limited | Export still → Memories / Chat |
| **WhatsApp / Telegram** | Desktop call + virtual cam where listed | Still → Status / chat photo |
| **LinkedIn Live** | RTMP / OBS | Still post |

**Vertical shorts:** Video Edit → TikTok / IG / Snap format → export → upload.

---

## Amateur — say this in AI Chat

Copy any line:

- `Virtual Cam for Zoom`
- `Teams camera setup`
- `Discord virtual camera`
- `WhatsApp still face swap`
- `Telegram desktop call cam`
- `Signal desktop camera`
- `Snapchat still export`
- `Go live Twitch NVENC`
- `Real-time face swap`
- `Still image face swap`
- `OBS manual setup`
- `Remember the 3 delivery paths`

AI replies guide the exact clicks. Pros use **OBS Stream** + **API Hub** boards; amateurs stay in **AI Chat**.
EOF

# Expand AI replies + quick prompts in main.dart
python3 << 'PY'
from pathlib import Path
p = Path('/home/workdir/artifacts/endless_cam_studio/lib/main.dart')
t = p.read_text()

# Insert more social replies before final return in _generateAiReply
needle = '    if (lower.contains(\'help\') || lower.contains(\'how\'))'
extra = r'''    if (lower.contains('zoom'))
      return "ZOOM: 1) Run python bridge/endless_engine.py  2) Zoom → Settings → Video → Camera → EndlessCam or OBS Virtual Camera. Real-time face swap: run your swap tool into that virtual cam first.";
    if (lower.contains('teams'))
      return "TEAMS: Devices → Camera → select EndlessCam / OBS Virtual Camera while endless_engine or OBS VC is running.";
    if (lower.contains('discord'))
      return "DISCORD: User Settings → Voice & Video → Camera → virtual device. Same Endless Cam feed.";
    if (lower.contains('whatsapp'))
      return "WHATSAPP: Desktop call may list virtual cam (OS-dependent). For still face swap: Face Swap → still → export image → send in chat or Status. Mobile apps rarely allow virtual cams.";
    if (lower.contains('telegram'))
      return "TELEGRAM Desktop: use virtual cam in calls when listed. Still swap: export photo → send. Stories: export vertical still.";
    if (lower.contains('signal'))
      return "SIGNAL: Desktop calls — select system virtual camera if exposed. Still face swap photo → attach in chat. Mobile: still export only.";
    if (lower.contains('snapchat') || lower.contains('snap'))
      return "SNAPCHAT: Mobile AR uses phone camera only. Use Still face swap → export → upload to Memories/Chat. Or post vertical clip from Video Edit.";
    if (lower.contains('meet') || lower.contains('google meet'))
      return "GOOGLE MEET: Gear → Video → choose EndlessCam/OBS VC (desktop Chrome + OS virtual cam).";
    if (lower.contains('skype') || lower.contains('webex') || lower.contains('slack'))
      return "Pick Virtual Cam in that app's video device list (Skype / Webex / Slack huddle) while the engine is running.";
    if (lower.contains('still') && lower.contains('face'))
      return "STILL FACE SWAP: Face Swap module → Static/Still mode → pick target → process → export PNG/JPG → post to WhatsApp, Telegram, IG, Snap, etc.";
    if (lower.contains('real-time') || lower.contains('realtime') || lower.contains('real time'))
      return "REAL-TIME FACE SWAP: Start swap tool → output to virtual cam → OBS or Zoom/Teams/Discord select that camera. Engine: python bridge/endless_engine.py";
    if (lower.contains('obs') && (lower.contains('manual') || lower.contains('setup') || lower.contains('integrate')))
      return "OBS MANUAL: Install OBS → Sources → Video Capture Device → EndlessCam. Start Virtual Camera. WebSocket port 4455 for app scene control. Stream tab or engine --rtmp --nvenc for public live. See SOCIAL_OBS_GUIDE.md";
'''

if "lower.contains('zoom')" not in t:
    if needle not in t:
        raise SystemExit('help needle missing')
    t = t.replace(needle, extra + needle, 1)
    print('social AI replies added')
else:
    print('zoom reply already present')

# Quick prompts for amateur
old = '''    final prompts = [
      '1 Virtual Cam for Zoom Teams',
      '2 WebRTC browser preview',
      '3 RTMP NVENC go live',
      'Remember the 3 delivery paths',
      'Start face swap',
      'Go live on Twitch',
      'Voice clone narration',
    ];'''
new = '''    final prompts = [
      'Virtual Cam for Zoom',
      'Teams camera setup',
      'Discord virtual camera',
      'WhatsApp still face swap',
      'Telegram desktop call cam',
      'Signal desktop camera',
      'Snapchat still export',
      'Real-time face swap',
      'Still image face swap',
      'OBS manual setup',
      'Go live Twitch NVENC',
      'Remember the 3 delivery paths',
    ];'''
if old in t:
    t = t.replace(old, new, 1)
    print('prompts updated')
else:
    print('prompts block changed?', 'Virtual Cam for Zoom Teams' in t)

p.write_text(t)
print('lines', len(t.splitlines()))
PY

# Copy guide + sync bridge nvenc to zip tree (already in endless_cam_studio)
cp /home/workdir/artifacts/endless_cam_studio/SOCIAL_OBS_GUIDE.md /home/workdir/artifacts/hollywood_studio_pro/ 2>/dev/null || true
cp /home/workdir/artifacts/endless_cam_studio/bridge/endless_engine.py /home/workdir/artifacts/hollywood_studio_pro/bridge/ 2>/dev/null || true

cd /home/workdir/artifacts
zip -qr Endless_Cam_Studio_all_OS.zip endless_cam_studio \
  -x '*/.venv/*' -x '*/__pycache__/*' -x '*/.dart_tool/*' -x '*/build/*'
ls -lh Endless_Cam_Studio_all_OS.zip
echo done
