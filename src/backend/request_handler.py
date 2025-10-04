from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
import requests
import os
from tempfile import NamedTemporaryFile

app = FastAPI()

# --- CONFIGURATION ---
Artur_TRANSCRIPTION_API_URL = "https://api.example.com/transcribe"
Ata_TIMESTAMP_API_URL = "https://api.example.com/get_timestamps"
API_KEY = os.getenv("API_KEY")


@app.post("/process-audio/")
async def process_audio(file: UploadFile = File(...)):
    """
    1. Accepts an audio file upload from the frontend
    2. Sends it to a transcription API to generate text
    3. Sends the text to another API to get timestamps
    4. Returns timestamps to the frontend
    """
    try:
        # --- Step 1: Save uploaded audio temporarily ---
        with NamedTemporaryFile(delete=False, suffix=".wav") as temp_audio:
            temp_audio.write(await file.read())
            temp_audio_path = temp_audio.name

        # --- Step 2: Send audio to transcription API ---
        with open(temp_audio_path, "rb") as audio_data:
            transcription_response = requests.post(
                TRANSCRIPTION_API_URL,
                headers={"Authorization": f"Bearer {API_KEY}"},
                files={"file": audio_data},
            )

        if transcription_response.status_code != 200:
            raise HTTPException(status_code=500, detail="Transcription API failed")

        transcription_text = transcription_response.json().get("text")
        if not transcription_text:
            raise HTTPException(status_code=500, detail="No transcription text returned")

        # --- Step 3: Get timestamps from another API ---
        timestamp_response = requests.post(
            TIMESTAMP_API_URL,
            headers={"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"},
            json={"text": transcription_text},
        )

        if timestamp_response.status_code != 200:
            raise HTTPException(status_code=500, detail="Timestamp API failed")

        timestamps = timestamp_response.json().get("timestamps", [])

        # --- Step 4: Return timestamps to frontend ---
        return JSONResponse(content={"timestamps": timestamps})

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    finally:
        # --- Cleanup temporary file ---
        if os.path.exists(temp_audio_path):
            os.remove(temp_audio_path)
