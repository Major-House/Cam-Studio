# Streaming latency optimizations

End-to-end path: **camera → process → virtual cam / RTMP → viewer**.

## Targets (order of magnitude)

| Path | Goal |
|------|------|
| Virtual cam (local Zoom/Teams) | **~40–150 ms** extra vs raw cam (720p30, low-latency flags) |
| RTMP to Twitch/YouTube | **1–5 s** typical (CDN + player); encoder should not add multi-second buffer |
| XTTS full WAV (Voice UI) | **0.5–2 s** short line on mid/high GPU |
| XTTS streaming first chunk | **~120–280 ms** on high-end GPU (needs streaming server) |

## What we optimized in the bridge

### RTMP (FFmpeg publish)
- `veryfast` default when preset was medium  
- **`tune=zerolatency`** (libx264)  
- **No B-frames** (`-bf 0`)  
- **Shorter GOP** (~1 s)  
- **Smaller VBV bufsize** (= bitrate, not 2×)  
- `flush_packets`  
- Unbuffered stdin for MJPEG frames  

### Virtual cam (FFmpeg → v4l2)
- `nobuffer`, `low_delay`, tiny probesize  
- Unbuffered pipe, MJPEG quality ~80  

### Frame ingest
- Prefer already-JPEG frames (skip re-encode)  
- Clients should use **~100 ms HTTP timeout** and **drop late frames** (Flutter `RtmpStreamer.pushFrame` already uses 100 ms)

### OBS WebSocket
- 2 s timeouts, connection reuse, reconnect on failure  

## Client recommendations

1. Cap pipeline at **720p30** for calls; 1080p60 for stage if GPU allows.  
2. Prefer **hardware encode** when available: `"videoCodec": "h264_nvenc"` in `/rtmp/start`.  
3. Do not block UI on frame POST — fire-and-forget / drop on timeout.  
4. For **voice in live calls**, use streaming TTS or pre-render VO; full-file XTTS is offline-oriented.  
5. Same machine: bridge on `127.0.0.1` only (no Wi-Fi hop).

## Measure

```bash
# RTMP stats
curl -s http://127.0.0.1:8766/rtmp/stats | python3 -m json.tool

# XTTS
python benchmark_xtts_latency.py
```

## Further gains (optional)

| Change | Effect |
|--------|--------|
| NVENC/QSV/AMF instead of x264 | Lower encode latency + CPU free |
| WebRTC / WHIP instead of RTMP | Lower glass-to-glass for custom players |
| XTTS `inference_stream` or streaming Docker | Sub-second first audio for voice |
| Shared memory / named pipe vs HTTP JPEG | Less copy for local frames |
| Disable idle last-frame spam when live | Tiny CPU win |

## Glass-to-glass reality check

Local virtual cam is limited by capture + process + OS cam stack.  
**RTMP to a public CDN cannot match local virtual-cam latency** — platform delay dominates. Optimize the encoder; accept CDN lag for public streams.
