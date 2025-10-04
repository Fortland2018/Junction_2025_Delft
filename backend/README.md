# Audio Waveform Backend

Backend w Pythonie do ekstrakcji waveform z plików audio/video.

## Instalacja

```bash
cd backend
pip install -r requirements.txt
```

## Uruchomienie

```bash
python main.py
```

Lub:

```bash
uvicorn main:app --reload --port 8000
```

API będzie dostępne na: http://localhost:8000

## Dokumentacja API

Automatyczna dokumentacja Swagger: http://localhost:8000/docs

## Endpointy

- `GET /` - Status serwera
- `POST /extract-waveform` - Ekstrakcja waveform z pliku audio/video
