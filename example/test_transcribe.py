# example_backend_usage.py
from transcriber.transcribe import transcribe_file, save_srt

result = transcribe_file(
    r"C:\Users\furtu\Downloads\What are Superconducting Qubits _ QuEra.mp4",
    model_size="base",     # or "large-v3" if you have a GPU
    device="cuda",            # or "cuda"
    gap_s=0.8,               # pause threshold to split sentences
    return_words=False       # set True if you also want raw word timings
)

print("Language:", result["language"])
for s in result["sentences"][:5]:
    print(f"{s['start']:6.2f}–{s['end']:6.2f}  {s['text']}")

# Optional: write an .srt file for the same output
save_srt(result["sentences"], "out/transcript.srt")
