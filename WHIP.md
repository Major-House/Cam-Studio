# WHIP (RFC 9725) — low-latency ingest

Modern alternative to RTMP for live **ingest** over WebRTC.

## Run

```bash
pip install aiortc av aiohttp numpy
export WHIP_TOKEN=secret123
python bridge/whip_server.py
# http://127.0.0.1:8788/whip/endpoint
```

## API

| Method | Path | Notes |
|--------|------|--------|
| OPTIONS | `/whip/endpoint` | Accept-Post: application/sdp |
| POST | `/whip/endpoint` | SDP offer → 201 + Location + answer |
| DELETE | `/whip/session/{id}` | End session |
| PATCH | `/whip/session/{id}` | Trickle ICE ack |
| Auth | Bearer token | When WHIP_TOKEN set |

## Pro settings

OBS Stream / API Hub → **Delivery 4 · WHIP**  
AI Chat (easy): `Setup WHIP stream`
