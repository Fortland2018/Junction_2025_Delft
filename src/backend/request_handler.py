from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse

# Import the transcribe and bad word flagger modules
from transcriber.transcribe import transcribe_bytes
from src.backend.bad_word_flagger import WordFlagger

# Import the hierarchical extremism detector (batch version with anonymization)
from src.ai.extremist_batch_two import HierarchicalExtremismDetector

app = FastAPI()

# Create single detector instance (reuse across requests)
_detector = HierarchicalExtremismDetector()
_flagger = WordFlagger()

@app.post("/process-media/")
async def process_media(file: UploadFile = File(...)):
    """
    1. Accepts an audio/video file upload from the frontend
    2. Transcribes it to text using the transcribe module
    3. Flags bad words using bad_word_flagger
    4. Runs hierarchical extremism analysis on the transcription text
    5. Returns JSON with transcription, flagged words, and extremism analysis
    """
    try:
        # Step 1: Read uploaded file bytes
        file_bytes = await file.read()

        # Step 2: Transcribe using transcribe_bytes
        transcribe_result = transcribe_bytes(file_bytes, filename_hint=file.filename)

        # Get the full transcription text by joining all sentences
        sentences = transcribe_result.get("sentences", [])
        # Be defensive: if a sentence lacks "text", use empty string
        transcription_text = " ".join([str(s.get("text", "")) for s in sentences]).strip()

        # Step 3: Flag bad words
        flagged_words = _flagger.flag_words(transcription_text)

        # Step 4: Extremism analysis (uses anonymization and parallel LLM calls internally)
        # analyze() returns dict with keys: scores, targets, raw_features, group_mapping
        extremism_analysis = await _detector.analyze_async(transcription_text)

        # Step 5: Return JSON response
        return JSONResponse(
            content={
                "transcription": sentences,
                "transcription_text": transcription_text,  # helpful for debugging
                "flagged_words": flagged_words,
                "extremism": {
                    "scores": extremism_analysis.get("scores", {}),
                    "targets": extremism_analysis.get("targets", {}),
                    "group_mapping": extremism_analysis.get("group_mapping", {}),
                    # Avoid dumping raw_features by default (can be huge). Uncomment if needed:
                    # "raw_features": extremism_analysis.get("raw_features", {}),
                },
            }
        )

    except Exception as e:
        # Surface concise error message
        raise HTTPException(status_code=500, detail=f"{type(e).__name__}: {e}")
