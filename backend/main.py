from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import librosa
import numpy as np
import tempfile
import os
from typing import List

app = FastAPI(title="Audio Waveform API", version="1.0.0")

# CORS dla Flutter web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {
        "status": "running",
        "service": "Audio Waveform Extractor",
        "version": "1.0.0"
    }

@app.post("/extract-waveform")
async def extract_waveform(file: UploadFile = File(...)):
    """
    Ekstrakcja waveform z pliku audio/video
    Zwraca znormalizowaną falę dźwiękową gotową do wyświetlenia
    """
    print(f"📁 Otrzymano plik: {file.filename}")
    
    # Sprawdź rozszerzenie
    allowed_extensions = ['mp3', 'wav', 'mp4', 'm4a', 'aac', 'flac', 'ogg', 'mov', 'avi']
    file_ext = file.filename.split('.')[-1].lower()
    
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Nieobsługiwane rozszerzenie: {file_ext}"
        )
    
    tmp_path = None
    
    try:
        # Zapisz plik tymczasowo
        with tempfile.NamedTemporaryFile(delete=False, suffix=f'.{file_ext}') as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name
        
        print(f"💾 Zapisano do: {tmp_path}")
        print(f"📊 Rozmiar: {len(content) / 1024 / 1024:.2f} MB")
        
        # Wczytaj audio (librosa automatycznie wyciąga audio z video!)
        print("🎵 Ładowanie audio...")
        y, sr = librosa.load(tmp_path, sr=22050, mono=True)
        
        duration = len(y) / sr
        print(f"⏱️  Długość: {duration:.2f}s")
        print(f"🔊 Sample rate: {sr} Hz")
        print(f"📈 Samples: {len(y)}")
        
        # Zmniejsz rozdzielczość do 500-1000 punktów (wystarczy dla waveform)
        target_samples = min(1000, len(y))
        
        if len(y) > target_samples:
            # Downsample
            hop_length = len(y) // target_samples
            y_downsampled = y[::hop_length][:target_samples]
        else:
            y_downsampled = y
        
        # Oblicz RMS (Root Mean Square) dla lepszej wizualizacji
        # Podziel na bloki i policz energię każdego bloku
        block_size = max(1, len(y) // target_samples)
        waveform = []
        
        for i in range(0, len(y), block_size):
            block = y[i:i + block_size]
            if len(block) > 0:
                rms = np.sqrt(np.mean(block**2))
                waveform.append(rms)
        
        # Przytnij do target_samples
        waveform = waveform[:target_samples]
        
        # Normalizuj do 0-255
        waveform_array = np.array(waveform)
        if waveform_array.max() > 0:
            waveform_normalized = ((waveform_array / waveform_array.max()) * 255).astype(int)
        else:
            waveform_normalized = np.zeros(len(waveform_array), dtype=int)
        
        print(f"✅ Waveform wygenerowany: {len(waveform_normalized)} punktów")
        
        return {
            "success": True,
            "waveform": waveform_normalized.tolist(),
            "sample_rate": int(sr),
            "duration": float(duration),
            "samples": len(waveform_normalized),
            "filename": file.filename,
            "file_size": len(content)
        }
    
    except Exception as e:
        print(f"❌ Błąd: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    
    finally:
        # Usuń plik tymczasowy
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)
            print("🗑️  Usunięto plik tymczasowy")

if __name__ == "__main__":
    import uvicorn
    print("🚀 Uruchamianie serwera...")
    print("📡 API dostępne na: http://localhost:8000")
    print("📖 Dokumentacja: http://localhost:8000/docs")
    uvicorn.run(app, host="0.0.0.0", port=8000)
