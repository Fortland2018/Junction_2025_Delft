#!/usr/bin/env python3
import sys, os, json, math, re
from pathlib import Path
import ffmpeg
from text_unidecode import unidecode
from faster_whisper import WhisperModel

# Config
MODEL_SIZE = "medium"          # "large-v3" for best quality if you have VRAM
DEVICE = "cuda" if os.environ.get("USE_CUDA","1") == "1" else "cpu"
COMPUTE_TYPE = "float16" if DEVICE == "cuda" else "int8"
PAUSE_GAP_S = 0.8              # split sentence if a gap >= this (seconds)
OUTPUT_DIR = "out"

PUNCT_RE = re.compile(r'([.!?])')

def ensure_wav(input_path, out_wav):
    Path(out_wav).parent.mkdir(parents=True, exist_ok=True)
    (
        ffmpeg
        .input(input_path)
        .output(out_wav, ac=1, ar=16000, format="wav", loglevel="error")
        .overwrite_output()
        .run()
    )

def to_srt_timestamp(seconds):
    ms = int(seconds * 1000)
    h = ms // 3600000; ms %= 3600000
    m = ms // 60000;   ms %= 60000
    s = ms // 1000;    ms %= 1000
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

def sentence_pack(words):
    """
    Greedy packing of word-level items into sentences by:
    - sentence-ending punctuation in ASR text
    - OR pauses >= PAUSE_GAP_S between consecutive words
    Each 'word' item: {'word','start','end'}
    """
    sentences = []
    cur = []
    last_end = None
    for w in words:
        if last_end is not None and (w["start"] - last_end) >= PAUSE_GAP_S and cur:
            sentences.append(cur); cur = []
        cur.append(w)
        last_end = w["end"]
        # If the word text ends with sentence punctuation, cut here
        if PUNCT_RE.search(w["word"]):
            sentences.append(cur); cur = []
            last_end = None
    if cur:
        sentences.append(cur)
    # Build final dicts
    out = []
    for sent_words in sentences:
        text = " ".join([w["word"] for w in sent_words]).strip()
        # normalize spacing around punctuation
        text = re.sub(r'\s+([,.!?])', r'\1', text)
        out.append({
            "start": round(sent_words[0]["start"], 2),
            "end": round(sent_words[-1]["end"], 2),
            "text": text
        })
    return out

def transcribe(wav_path):
    model = WhisperModel(MODEL_SIZE, device=DEVICE, compute_type=COMPUTE_TYPE)
    segments, info = model.transcribe(
        wav_path,
        beam_size=5,
        vad_filter=True,
        vad_parameters=dict(min_silence_duration_ms=500),
        word_timestamps=True  # critical: we want per-word times
    )
    words = []
    for seg in segments:
        for w in seg.words or []:
            # faster-whisper may include punctuation as separate items; keep them
            words.append({"word": w.word, "start": w.start, "end": w.end})
    return sentence_pack(words)

def main():
    if len(sys.argv) != 2:
        print("Usage: python transcribe_to_sentences.py <audio_or_video_file>")
        sys.exit(2)
    src = sys.argv[1]
    base = Path(src).stem
    Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)
    wav_path = os.path.join(OUTPUT_DIR, base + ".wav")
    ensure_wav(src, wav_path)
    sentences = transcribe(wav_path)

    # Write JSONL
    jsonl_path = os.path.join(OUTPUT_DIR, base + ".jsonl")
    with open(jsonl_path, "w", encoding="utf-8") as f:
        for s in sentences:
            f.write(json.dumps(s, ensure_ascii=False) + "\n")

    # Write SRT
    srt_path = os.path.join(OUTPUT_DIR, base + ".srt")
    with open(srt_path, "w", encoding="utf-8") as f:
        for i, s in enumerate(sentences, 1):
            f.write(f"{i}\n{to_srt_timestamp(s['start'])} --> {to_srt_timestamp(s['end'])}\n{s['text']}\n\n")

    print(f"Done.\nJSONL: {jsonl_path}\nSRT:   {srt_path}")

if __name__ == "__main__":
    main()
