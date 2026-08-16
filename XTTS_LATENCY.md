# Coqui XTTS-v2 latency benchmarks

Reference numbers for planning Studio Pro voice cloning.  
**RTF** = wall time ÷ audio duration (lower is faster; RTF &lt; 1 means faster than real-time playback).

Sources are third-party published benches (hardware/method differ). Always measure on your machine with `benchmark_xtts_latency.py`.

---

## GPU — full clip generation (~30 s audio)

Approximate end-to-end latency for a **~30 second** speech clip (single request, FP16-class setups):

| GPU | Latency (~30 s audio) | RTF | Notes |
|-----|------------------------|-----|--------|
| RTX 5090 | ~2.1 s | ~0.07 | ~14× real-time |
| RTX 5080 | ~3.6 s | ~0.12 | Strong interactive |
| RTX 3090 | ~5.4 s | ~0.18 | Solid value |
| RTX 4060 Ti | ~8.4 s | ~0.28 | OK for VO / offline |
| RTX 4060 | ~11.7 s | ~0.39 | Usable offline |
| RTX 3050 | ~25.5 s | ~0.85 | Still &lt; 1.0 RTF |

Published GPU suite (30 s clip methodology).

---

## GPU — short sentence (full vs first audio)

~15-word English sentence, ~6 s reference clone sample:

| GPU | Full generation | Time to first audio (streaming) |
|-----|-----------------|----------------------------------|
| RTX 5090 | ~310 ms | ~120 ms |
| RTX 5080 | ~480 ms | ~185 ms |
| RTX 3090 | ~720 ms | ~280 ms |
| RTX 4060 Ti | ~1050 ms | — |
| RTX 4060 | ~1450 ms | — |
| RTX 3050 | ~2400 ms | — |

Streaming cuts **perceived** latency a lot; Studio Pro’s adapter currently returns a full WAV (non-streaming). Streaming would need `inference_stream` / a streaming server.

---

## GPU — generate 10 s of audio (another suite)

| Model | RTX 3090 | Faster high-end GPU | RTF (top card, that suite) |
|-------|----------|---------------------|----------------------------|
| XTTS v2 | ~3.8 s | ~1.6–2.4 s | ~0.16–0.24 |
| F5-TTS | ~2.9 s | ~1.2–1.8 s | ~0.12–0.18 |
| StyleTTS 2 | ~1.4 s | ~0.6–0.9 s | ~0.06–0.09 |
| Piper (CPU) | ~0.15 s | ~0.15 s | ~0.015 |

XTTS is slower than lightweight TTS but adds **zero-shot cloning**.

---

## CPU-only (no GPU)

One CPU-only study (8 cores, many sentences): **XTTS-v2 RTF ≈ 5.3**, mean wall ~**21 s per utterance** — not interactive for chat. Prefer GPU for the Voice module.

Older community notes: CPU often **slower than real-time**; GPU typically **2–10×+** real-time depending on card and DeepSpeed.

---

## DeepSpeed / first-chunk (historical Coqui notes)

With DeepSpeed, public demos reported roughly:
- First audio chunk **~200 ms**
- RTF around **0.25** (setup-dependent)

DeepSpeed can help 2–3× on some stacks (e.g. xtts-api-server `--deepspeed`).

---

## What this means for Studio Pro

| Use case | Guidance |
|----------|----------|
| Film / short **VO offline** | Any mid GPU fine; batch lines |
| Interactive **Voice** UI | Prefer RTX 3060-class or better; expect ~0.5–2 s for short lines on modern cards |
| Live call “instant” TTS | Full-file XTTS is rarely sub-200 ms without **streaming**; use streaming server or a lighter engine for live |
| CPU laptop | Demo / short tests only |

**VRAM:** XTTS-v2 weights often ~**2–2.5 GB** FP16, plus runtime buffers.

---

## Run your own bench

```bash
cd bridge
# adapter deps already installed
python benchmark_xtts_latency.py
# optional: XTTS_DEVICE=cuda python benchmark_xtts_latency.py
```

Writes JSON lines with wall_ms, RTF, device, text length. Compare to the tables above.

---

## Studio path latency (extra)

App → bridge `:8766` → adapter `:8777` adds **network + JSON** overhead (usually **&lt; 50 ms** on localhost). Dominant cost is **model inference**, not the proxy.
