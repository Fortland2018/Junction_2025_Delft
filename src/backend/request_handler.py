from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse

# Import the transcribe and bad word flagger modules
from transcriber.transcribe import transcribe_bytes
from src.backend.bad_word_flagger import WordFlagger

app = FastAPI()


@app.post("/process-media/")
async def process_media(file: UploadFile = File(...)):
    """
    1. Accepts an audio/video file upload from the frontend
    2. Transcribes it to text using the transcribe module
    3. Flags bad words using bad_word_flagger
    4. Returns JSON with transcription and flagged words
    """
    try:
        # Step 1: Read uploaded file bytes
        file_bytes = await file.read()

        # Step 2: Transcribe using transcribe_bytes
        transcribe_result = transcribe_bytes(file_bytes, filename_hint=file.filename)
        # Get the full transcription text by joining all sentences
        sentences = transcribe_result.get("sentences", [])
        transcription_text = " ".join([s["text"] for s in sentences])

        # Step 3: Flag bad words
        flagger = WordFlagger()
        flagged_words = flagger.flag_words(transcription_text)

        # Step 4: Return JSON response
        return JSONResponse(content={
            "transcription": sentences,
            "flagged_words": flagged_words
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
