#!/usr/bin/env python3
"""
Coqui XTTS adapter for Hollywood Studio Pro
============================================
Implements the simple contract expected by virtual_cam_bridge.py:

  GET  /health
  GET  /speakers
  POST /clone   JSON { text, speakerId, referencePath?, language?, speed? }
               → audio/wav bytes

Run (GPU recommended):
  pip install TTS torch torchaudio flask
  # Accept Coqui terms if required by your install
  export COQUI_TOS_AGREED=1
  python coqui_xtts_adapter.py

Then point the studio bridge at this service:
  export VOICE_CLONE_URL=http://127.0.0.1:8777
  python virtual_cam_bridge.py

Model: tts_models/multilingual/multi-dataset/xtts_v2
Voice clone: pass referencePath to a short clean WAV (6–15s, one speaker).
"""

from __future__ import annotations

import io
import logging
import os
import tempfile
import threading
from pathlib import Path
from typing import Any, Optional

import numpy as np
from flask import Flask, request, jsonify, send_file

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("xtts-adapter")

app = Flask(__name__)

_MODEL_NAME = os.environ.get(
    "XTTS_MODEL", "tts_models/multilingual/multi-dataset/xtts_v2"
)
_DEVICE = os.environ.get("XTTS_DEVICE", "")  # "cuda", "cpu", or empty = auto
_DEFAULT_LANG = os.environ.get("XTTS_LANGUAGE", "en")
_SPEAKER_DIR = Path(os.environ.get("XTTS_SPEAKER_DIR", "speakers"))
_lock = threading.Lock()
_tts = None

# Built-in XTTS preset speaker names (subset; model has more)
_PRESET_SPEAKERS = [
    {"id": "default", "name": "Studio Default", "xtts": "Ana Florence"},
    {"id": "narrator", "name": "Film Narrator", "xtts": "Craig Gutsy"},
    {"id": "hero", "name": "Hero Lead", "xtts": "Damien Black"},
    {"id": "custom1", "name": "Custom Clone 1", "xtts": None},  # needs reference wav
]


def _device() -> str:
    if _DEVICE:
        return _DEVICE
    try:
        import torch
        return "cuda" if torch.cuda.is_available() else "cpu"
    except Exception:
        return "cpu"


def _get_tts():
    global _tts
    with _lock:
        if _tts is not None:
            return _tts
        log.info("Loading XTTS model %s on %s …", _MODEL_NAME, _device())
        from TTS.api import TTS
        tts = TTS(_MODEL_NAME)
        tts.to(_device())
        _tts = tts
        log.info("XTTS ready")
        return _tts


def _resolve_speaker(speaker_id: str, reference_path: Optional[str]):
    """Return (speaker_name_or_None, speaker_wav_or_None)."""
    if reference_path and os.path.isfile(reference_path):
        return None, reference_path

    # Named custom sample under speakers/
    cand = _SPEAKER_DIR / f"{speaker_id}.wav"
    if cand.is_file():
        return None, str(cand)

    for p in _PRESET_SPEAKERS:
        if p["id"] == speaker_id:
            if p["xtts"]:
                return p["xtts"], None
            # custom1 without file
            break

    # Fall back to first preset with an XTTS name
    return "Ana Florence", None


def _wav_bytes_from_tts(tts, text: str, language: str, speaker: Optional[str],
                        speaker_wav: Optional[str], speed: float) -> bytes:
    # TTS API writes file most reliably across versions
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    try:
        kwargs: dict[str, Any] = {
            "text": text,
            "file_path": path,
            "language": language,
        }
        if speaker_wav:
            kwargs["speaker_wav"] = speaker_wav
        elif speaker:
            kwargs["speaker"] = speaker
        # speed not uniformly supported on all XTTS builds — try soft
        try:
            tts.tts_to_file(**kwargs, speed=speed)
        except TypeError:
            tts.tts_to_file(**kwargs)
        with open(path, "rb") as f:
            return f.read()
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


@app.route("/health", methods=["GET"])
def health():
    try:
        _get_tts()
        return jsonify({"ok": True, "model": _MODEL_NAME, "device": _device()})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/speakers", methods=["GET"])
def speakers():
    items = [{"id": p["id"], "name": p["name"]} for p in _PRESET_SPEAKERS]
    if _SPEAKER_DIR.is_dir():
        for wav in sorted(_SPEAKER_DIR.glob("*.wav")):
            sid = wav.stem
            if not any(x["id"] == sid for x in items):
                items.append({"id": sid, "name": f"Clone: {sid}"})
    return jsonify({"speakers": items, "engine": "coqui-xtts_v2"})


@app.route("/clone", methods=["POST"])
def clone():
    cfg = request.get_json(force=True, silent=True) or {}
    text = (cfg.get("text") or "").strip()
    if not text:
        return jsonify({"error": "text required"}), 400

    speaker_id = cfg.get("speakerId") or "default"
    reference = cfg.get("referencePath")
    language = cfg.get("language") or _DEFAULT_LANG
    speed = float(cfg.get("speed") or 1.0)

    try:
        tts = _get_tts()
        speaker, speaker_wav = _resolve_speaker(speaker_id, reference)
        with _lock:
            audio = _wav_bytes_from_tts(
                tts, text, language, speaker, speaker_wav, speed
            )
        return app.response_class(audio, mimetype="audio/wav")
    except Exception as e:
        log.exception("clone failed")
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    _SPEAKER_DIR.mkdir(parents=True, exist_ok=True)
    port = int(os.environ.get("XTTS_PORT", "8777"))
    # Preload model in background so /health is honest after warmup
    threading.Thread(target=lambda: _get_tts(), daemon=True).start()
    log.info("Coqui XTTS adapter on http://127.0.0.1:%s", port)
    log.info("Put reference WAVs in %s for custom clones", _SPEAKER_DIR.resolve())
    app.run(host="127.0.0.1", port=port, threaded=True)
