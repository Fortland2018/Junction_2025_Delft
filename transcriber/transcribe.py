# file: transcriber/transcribe.py
# Purpose: Call from your backend to transcribe any audio/video file into sentence-level
#          timestamps (and optionally word-level), without running an HTTP server.

import os
import re
import tempfile
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Any

from faster_whisper import WhisperModel

__all__ = [
    "transcribe_file",
    "transcribe_bytes",
    "save_srt",
]

# ----------------------------
# Default configuration
# ----------------------------
DEFAULT_MODEL = os.environ.get("FW_MODEL", "base")   # "base"|"small"|"medium"|"large-v3"
DEFAULT_DEVICE = os.environ.get("FW_DEVICE", "cpu")    # "cpu"|"cuda"
DEFAULT_COMPUTE = "int8" if DEFAULT_DEVICE == "cpu" else "float16"
DEFAULT_GAP_S = float(os.environ.get("SENTENCE_GAP_S", "0.8"))
FFMPEG_BIN = os.environ.get("FFMPEG_BIN")  # set full path if ffmpeg isn't on PATH

_SENT_PUNCT = re.compile(r"\s+([,.!?])")

_MODEL_CACHE: Dict[tuple, WhisperModel] = {}


# ----------------------------
# Internal utilities
# ----------------------------
def _which_ffmpeg() -> str:
    """Find ffmpeg executable (env override wins)."""
    if FFMPEG_BIN and Path(FFMPEG_BIN).exists():
        return FFMPEG_BIN
    from shutil import which
    found = which("ffmpeg")
    if found:
        return found
    raise RuntimeError(
        "FFmpeg not found. Install it and/or set FFMPEG_BIN to its full path. "
        "Windows: winget install -e --id Gyan.FFmpeg"
    )


def _extract_wav(src_path: str) -> str:
    """
    Extract mono 16 kHz WAV from any audio/video. Returns temp WAV path.
    """
    ffmpeg = _which_ffmpeg()
    wav_path = os.path.join(
        tempfile.gettempdir(),
        Path(src_path).stem + "_16k_mono.wav"
    )
    cmd = [
        ffmpeg, "-y",
        "-i", src_path,
        "-vn",            # ignore video
        "-ac", "1",       # mono
        "-ar", "16000",   # 16 kHz
        wav_path
    ]
    # Suppress ffmpeg console spam; raise on error
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return wav_path


def _load_model(size: str, device: str, compute_type: str) -> WhisperModel:
    key = (size, device, compute_type)
    mdl = _MODEL_CACHE.get(key)
    if mdl is None:
        mdl = WhisperModel(size, device=device, compute_type=compute_type)
        _MODEL_CACHE[key] = mdl
    return mdl


def _pack_sentences(words: List[dict], gap_s: float) -> List[dict]:
    """
    Greedy packing of words into sentence-like chunks using punctuation or pauses >= gap_s.
    Input word items: {"w": token, "s": start_sec, "e": end_sec}
    Output items: {"start": float, "end": float, "text": str}
    """
    out: List[dict] = []
    cur: List[dict] = []
    last_end: Optional[float] = None

    def flush():
        if not cur:
            return
        text = " ".join(w["w"] for w in cur).strip()
        text = _SENT_PUNCT.sub(r"\1", text)  # tighten spaces before punctuation
        out.append({
            "start": round(cur[0]["s"], 2),
            "end": round(cur[-1]["e"], 2),
            "text": text
        })
        cur.clear()

    for w in words:
        s, e, tok = w["s"], w["e"], w["w"]
        if last_end is not None and (s - last_end) >= gap_s and cur:
            flush()
        cur.append(w)
        last_end = e
        if tok.endswith((".", "!", "?")):
            flush()
            last_end = None
    flush()
    return out


# ----------------------------
# Public API
# ----------------------------
def transcribe_file(
    src_path: str,
    model_size: str = DEFAULT_MODEL,
    device: str = DEFAULT_DEVICE,
    compute_type: Optional[str] = None,
    gap_s: float = DEFAULT_GAP_S,
    word_timestamps: bool = True,
    return_words: bool = False,
) -> Dict[str, Any]:
    """
    Transcribe an audio or video file into sentence-level timestamps.

    Args:
        src_path: Path to audio or video file.
        model_size: Whisper model size ("base"|"small"|"medium"|"large-v3"). Default: env FW_MODEL or "medium".
        device: "cpu" or "cuda". Default: env FW_DEVICE or "cpu".
        compute_type: Whisper compute type; default: "int8" on CPU, "float16" on CUDA.
        gap_s: Pause threshold (seconds) to split sentences when no punctuation.
        word_timestamps: If True, request word-level times from Whisper (recommended).
        return_words: If True, include the raw word list in the return payload.

    Returns:
        {
          "language": "en",
          "sentences": [ {"start": 1.02, "end": 3.84, "text": "..."} , ... ],
          "words": [ {"w":"Hello","s":0.10,"e":0.32}, ... ]   # present only if return_words=True
        }
    """
    if compute_type is None:
        compute_type = "int8" if device == "cpu" else "float16"

    # 1) Ensure we have a 16k mono wav
    wav_path = _extract_wav(src_path)

    # 2) Load/cached model
    model = _load_model(model_size, device, compute_type)

    # 3) Transcribe
    segments, info = model.transcribe(
        wav_path,
        beam_size=5,
        vad_filter=True,
        vad_parameters=dict(min_silence_duration_ms=500),
        word_timestamps=word_timestamps
    )

    # 4) Collect words (if available)
    words: List[dict] = []
    if word_timestamps:
        for seg in segments:
            if seg.words:
                for w in seg.words:
                    words.append({"w": w.word, "s": float(w.start or 0.0), "e": float(w.end or 0.0)})
    else:
        # Fall back to segment-level timing if word timestamps were disabled
        for seg in segments:
            words.append({"w": seg.text.strip(), "s": float(seg.start), "e": float(seg.end)})

    # 5) Build sentences
    sentences = _pack_sentences(words, gap_s=gap_s)

    # 6) Cleanup temp wav
    try:
        os.remove(wav_path)
    except Exception:
        pass

    result: Dict[str, Any] = {"language": info.language, "sentences": sentences}
    if return_words:
        result["words"] = words
    return result


def transcribe_bytes(
    data: bytes,
    filename_hint: str = "upload.mp4",
    **kwargs
) -> Dict[str, Any]:
    """
    Same as transcribe_file, but accepts raw bytes (e.g., when you received a file stream).
    We write to a secure temp file, then call transcribe_file().

    Args:
        data: File content in bytes.
        filename_hint: Used only to choose an extension for FFmpeg (e.g., ".mp4", ".wav").

    Returns: Same dict as transcribe_file().
    """
    suffix = Path(filename_hint).suffix or ".bin"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(data)
        tmp_path = tmp.name
    try:
        return transcribe_file(tmp_path, **kwargs)
    finally:
        try:
            os.remove(tmp_path)
        except Exception:
            pass


def save_srt(sentences: list[dict], srt_path: str) -> None:
    from pathlib import Path

    def _fmt(ts: float) -> str:
        ms = int(round(ts * 1000))
        h, ms = divmod(ms, 3600000)
        m, ms = divmod(ms, 60000)
        s, ms = divmod(ms, 1000)
        return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

    p = Path(srt_path)
    if p.parent and not p.parent.exists():
        p.parent.mkdir(parents=True, exist_ok=True)

    lines = []
    for i, s in enumerate(sentences, 1):
        lines.append(str(i))
        lines.append(f"{_fmt(s['start'])} --> {_fmt(s['end'])}")
        lines.append(s["text"].strip())
        lines.append("")
    p.write_text("\n".join(lines), encoding="utf-8")
