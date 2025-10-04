from faster_whisper import WhisperModel
import subprocess
import os

# --- CONFIGURATION ---
AUDIO_PATH = "C:\\Users\\furtu\\Downloads\\What are Superconducting Qubits _ QuEra.mp4"   # can also be .wav, .mp4, .mkv, etc.
MODEL_SIZE = "base"         # or 'small', 'medium', 'large-v2'

# --- IF FILE IS VIDEO, EXTRACT AUDIO FIRST ---
if AUDIO_PATH.endswith((".mp4", ".mkv", ".avi")):
    audio_out = "temp_audio.wav"
    subprocess.run(
        ["ffmpeg", "-y", "-i", AUDIO_PATH, "-vn", "-ac", "1", "-ar", "16000", audio_out],
        check=True
    )
    AUDIO_PATH = audio_out

# --- LOAD MODEL ---
print(f"Loading Whisper model ({MODEL_SIZE})...")
model = WhisperModel(MODEL_SIZE, device="cpu", compute_type="int8")  # change to 'cuda' if GPU

# --- TRANSCRIBE ---
segments, info = model.transcribe(AUDIO_PATH, beam_size=5)

print(f"Detected language: {info.language}")
print("\n--- TRANSCRIPTION ---\n")

for segment in segments:
    start = round(segment.start, 2)
    end = round(segment.end, 2)
    text = segment.text.strip()
    print(f"[{start:>7.2f} --> {end:>7.2f}] {text}")

print("\nTranscription complete ✅")
