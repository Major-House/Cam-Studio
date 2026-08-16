#!/usr/bin/env python3
"""
Benchmark Coqui XTTS-v2 latency for Hollywood Studio Pro.
Measures wall time and RTF (wall / audio duration) for several text lengths.

Usage:
  export COQUI_TOS_AGREED=1
  python benchmark_xtts_latency.py
  XTTS_DEVICE=cpu python benchmark_xtts_latency.py
"""

from __future__ import annotations

import json
import os
import time
import wave
from pathlib import Path

TEXTS = [
    ("short", "Welcome to the studio."),
    ("medium", "Welcome to Hollywood Studio Pro. This line tests medium length narration for voice over."),
    (
        "long",
        "In the final act the hero faces the impossible choice, while the city burns behind them "
        "and the score swells toward silence. This longer passage stresses encoder throughput.",
    ),
]


def audio_duration_s(path: str) -> float:
    with wave.open(path, "rb") as w:
        return w.getnframes() / float(w.getframerate())


def main() -> None:
    device = os.environ.get("XTTS_DEVICE") or (
        "cuda"
        if __import__("torch").cuda.is_available()
        else "cpu"
    )
    model = os.environ.get(
        "XTTS_MODEL", "tts_models/multilingual/multi-dataset/xtts_v2"
    )
    print(f"Device={device} model={model}")
    from TTS.api import TTS

    t0 = time.perf_counter()
    tts = TTS(model).to(device)
    load_s = time.perf_counter() - t0
    print(f"Model load: {load_s:.2f}s")

    out_dir = Path("bench_out")
    out_dir.mkdir(exist_ok=True)
    results = []

    # Warmup
    warm = out_dir / "warmup.wav"
    tts.tts_to_file(text="Warmup.", file_path=str(warm), language="en", speaker="Ana Florence")

    for name, text in TEXTS:
        path = out_dir / f"{name}.wav"
        times = []
        for i in range(3):
            t1 = time.perf_counter()
            tts.tts_to_file(
                text=text,
                file_path=str(path),
                language="en",
                speaker="Ana Florence",
            )
            times.append(time.perf_counter() - t1)
        # drop first of the three if you want colder starts; we average all after global warmup
        wall = sum(times) / len(times)
        dur = audio_duration_s(str(path))
        rtf = wall / dur if dur > 0 else None
        row = {
            "label": name,
            "chars": len(text),
            "wall_s": round(wall, 3),
            "audio_s": round(dur, 3),
            "rtf": round(rtf, 3) if rtf else None,
            "device": device,
        }
        results.append(row)
        print(
            f"{name:8} chars={len(text):3} wall={wall:.3f}s audio={dur:.3f}s RTF={rtf:.3f}"
        )

    summary = {
        "load_s": round(load_s, 3),
        "device": device,
        "model": model,
        "runs": results,
    }
    out_json = out_dir / "latency_summary.json"
    out_json.write_text(json.dumps(summary, indent=2))
    print(f"Wrote {out_json}")


if __name__ == "__main__":
    main()
