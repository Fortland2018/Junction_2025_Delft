from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import librosa
import numpy as np
import tempfile
import os
import sys
from typing import List
import json
from datetime import datetime

# Add parent directory to path to import from src
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from transcriber.transcribe import transcribe_bytes
from src.backend.bad_word_flagger import WordFlagger
from src.ai.extremist_batch_two import HierarchicalExtremismDetector

app = FastAPI(title="Audio Analysis API", version="1.0.0")

# Create single detector instance (reuse across requests)
_detector = HierarchicalExtremismDetector()
_flagger = WordFlagger()

# Pydantic models for request bodies
class WordRequest(BaseModel):
    word: str

# CORS for Flutter web
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
        "service": "Audio Analysis API",
        "version": "1.0.0"
    }

@app.post("/extract-waveform")
async def extract_waveform(file: UploadFile = File(...)):
    """Extract waveform from audio/video file"""
    print(f"📁 Received file: {file.filename}")
    
    allowed_extensions = ['mp3', 'wav', 'mp4', 'm4a', 'aac', 'flac', 'ogg', 'mov', 'avi']
    file_ext = file.filename.split('.')[-1].lower()
    
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported extension: {file_ext}"
        )
    
    tmp_path = None
    
    try:
        # Save file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=f'.{file_ext}') as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name
        
        print(f"💾 Saved to: {tmp_path}")
        print(f"📊 Size: {len(content) / 1024 / 1024:.2f} MB")
        
        # Load audio
        print("🎵 Loading audio...")
        y, sr = librosa.load(tmp_path, sr=22050, mono=True)
        
        duration = len(y) / sr
        print(f"⏱️ Duration: {duration:.2f}s")
        
        # Reduce resolution to 500-1000 points
        target_samples = min(1000, len(y))
        
        if len(y) > target_samples:
            hop_length = len(y) // target_samples
            y_downsampled = y[::hop_length][:target_samples]
        else:
            y_downsampled = y
        
        # Calculate RMS for better visualization
        block_size = max(1, len(y) // target_samples)
        waveform = []
        
        for i in range(0, len(y), block_size):
            block = y[i:i + block_size]
            if len(block) > 0:
                rms = np.sqrt(np.mean(block**2))
                waveform.append(rms)
        
        waveform = waveform[:target_samples]
        
        # Normalize to 0-255
        waveform_array = np.array(waveform)
        if waveform_array.max() > 0:
            waveform_normalized = ((waveform_array / waveform_array.max()) * 255).astype(int)
        else:
            waveform_normalized = np.zeros(len(waveform_array), dtype=int)
        
        print(f"✅ Waveform generated: {len(waveform_normalized)} points")
        
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
        import traceback
        error_details = traceback.format_exc()
        print(f"❌ Error: {str(e)}")
        print(f"📋 Details:\n{error_details}")
        raise HTTPException(status_code=500, detail=f"{str(e)}\n\nTraceback: {error_details}")
    
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)
            print("🗑️ Removed temporary file")

@app.post("/process-media/")
async def process_media(file: UploadFile = File(...)):
    """
    Process audio/video file:
    1. Transcribes to text
    2. Flags bad words
    3. Batch analyzes all sentences for extremism
    4. Categorizes and returns processed data
    """
    
    def categorize_score(score):
        """Categorize numerical score into None, Low, Medium, High"""
        if score < 2.0:
            return {"level": "None", "color": "#48BB78", "icon": "check_circle"}
        elif score < 5.0:
            return {"level": "Low", "color": "#ECC94B", "icon": "info"}
        elif score < 7.5:
            return {"level": "Medium", "color": "#ED8936", "icon": "warning"}
        else:
            return {"level": "High", "color": "#E53E3E", "icon": "error"}
    
    try:
        print(f"📁 Processing file: {file.filename}")
        
        # Step 1: Read file
        file_bytes = await file.read()
        print(f"📦 Size: {len(file_bytes) / 1024 / 1024:.2f} MB")

        # Step 2: Transcribe
        print("🎵 Transcribing audio...")
        transcribe_result = transcribe_bytes(file_bytes, filename_hint=file.filename)
        sentences = transcribe_result.get("sentences", [])
        transcription_text = " ".join([str(s.get("text", "")) for s in sentences]).strip()
        print(f"📝 Transcription completed: {len(sentences)} sentences, {len(transcription_text)} characters")

        # Step 3: Flag bad words
        print("🚩 Detecting inappropriate words...")
        flagged_words = _flagger.flag_words(transcription_text)
        print(f"🚩 Found {len(flagged_words)} flagged sentences")

        # Step 4: Batch analyze ALL sentences using the batch method
        print(f"🔍 Batch analyzing {len(sentences)} sentences...")
        
        # Prepare batch input - list of dicts with id and text
        batch_input = [
            {
                'id': idx,
                'text': s.get('text', '').strip()
            }
            for idx, s in enumerate(sentences)
            if s.get('text', '').strip()  # Only non-empty sentences
        ]
        
        # Use the async batch method directly (we're in an async context)
        batch_results = await _detector._batch_analyze_async(batch_input)
        print(f"✅ Batch analysis completed for {len(batch_results)} sentences")
        
        # Category colors for frontend
        category_colors = {
            'violence_advocacy': '#E53E3E',
            'dehumanization': '#9F7AEA',
            'outgroup_homogenization': '#38B2AC',
            'threat_inflation': '#ED8936',
            'absolutism': '#ECC94B',
        }
        
        category_names = {
            'violence_advocacy': 'Violence Advocacy',
            'dehumanization': 'Dehumanization',
            'outgroup_homogenization': 'Outgroup Homogenization',
            'threat_inflation': 'Threat Inflation',
            'absolutism': 'Absolutism',
        }
        
        # Step 5: Process each sentence with its individual analysis
        processed_sentences = []
        all_dimension_scores = {
            'violence_advocacy': [],
            'dehumanization': [],
            'outgroup_homogenization': [],
            'threat_inflation': [],
            'absolutism': []
        }
        
        for idx, sentence in enumerate(sentences):
            # Find corresponding batch result
            batch_result = None
            for result in batch_results:
                if result.get('text_id') == idx:
                    batch_result = result
                    break
            
            if batch_result is None or 'error' in batch_result:
                # Fallback for missing/error results
                processed_sentence = {
                    'text': sentence.get('text', ''),
                    'start': sentence.get('start', 0),
                    'end': sentence.get('end', 0),
                    'category': 'Transcription',
                    'color': '#667EEA',
                    'level': 'None'
                }
                processed_sentences.append(processed_sentence)
                continue
            
            # Get this sentence's scores
            sentence_scores = batch_result.get('scores', {})
            
            # Find the highest scoring dimension
            dominant_category = None
            highest_score = 0.0
            
            for dimension in ['violence_advocacy', 'dehumanization', 
                            'outgroup_homogenization', 'threat_inflation', 'absolutism']:
                if dimension in sentence_scores:
                    score_data = sentence_scores[dimension]
                    if isinstance(score_data, dict) and 'score' in score_data:
                        score = score_data['score']
                    elif isinstance(score_data, (int, float)):
                        score = score_data
                    else:
                        score = 0.0
                    
                    # Collect for overall aggregation
                    all_dimension_scores[dimension].append(score)
                    
                    if score > highest_score:
                        highest_score = score
                        dominant_category = dimension
            
            # Determine category and level based on this sentence's score
            # Check both vocabulary filter AND extremism categories
            sentence_text = sentence.get('text', '')
            words_in_sentence = [word.lower().strip() for word in sentence_text.split()]
            has_filtered_word = any(word in _flagger.bad_words for word in words_in_sentence)
            
            # Check for extremism category
            extremism_category = None
            extremism_level = 'None'
            extremism_color = None
            
            if dominant_category and highest_score >= 2.0:
                extremism_category = category_names[dominant_category]
                category_info = categorize_score(highest_score)
                extremism_level = category_info['level']
                extremism_color = category_colors.get(dominant_category, '#667EEA')
            
            # Determine primary category and secondary categories
            categories = []
            
            if has_filtered_word:
                categories.append('Vocabulary Filter')
                color = '#ED8936'  # Orange for vocabulary filter
                level = 'Flagged'
                print(f"  🚩 Vocabulary Filter: \"{sentence_text[:50]}...\"")
            
            if extremism_category:
                categories.append(extremism_category)
                # If not already colored by vocab filter, use extremism color
                if not has_filtered_word:
                    color = extremism_color
                    level = extremism_level
                print(f"  ⚠️ Sentence {idx}: {extremism_category} ({extremism_level}, score={highest_score:.1f}) - \"{sentence_text[:50]}...\"")
            
            # If no categories, it's just transcription
            if not categories:
                categories.append('Transcription')
                color = '#667EEA'
                level = 'None'
            
            # Primary category is the first one (vocab filter has priority for display)
            primary_category = categories[0]
            
            processed_sentence = {
                'text': sentence.get('text', ''),
                'start': sentence.get('start', 0),
                'end': sentence.get('end', 0),
                'category': primary_category,
                'categories': categories,  # All applicable categories
                'color': color,
                'level': level
            }
            
            processed_sentences.append(processed_sentence)
        
        # Step 6: Calculate overall scores by aggregating sentence scores
        overall_categorized_scores = {}
        
        for dimension in ['violence_advocacy', 'dehumanization', 
                         'outgroup_homogenization', 'threat_inflation', 'absolutism']:
            scores = all_dimension_scores[dimension]
            if scores:
                # Use max score as overall (most concerning sentence)
                max_score = max(scores)
                avg_score = sum(scores) / len(scores)
                
                # Overall is max score with slight contribution from average
                overall_score = max_score + (0.1 * avg_score)
                overall_score = min(10.0, overall_score)  # Cap at 10
            else:
                overall_score = 0.0
            
            category_info = categorize_score(overall_score)
            overall_categorized_scores[dimension] = {
                'score': overall_score,
                'level': category_info['level'],
                'color': category_info['color'],
                'icon': category_info['icon']
            }
            print(f"  📊 Overall {dimension}: {overall_score:.1f} → {category_info['level']}")
        
        # Calculate overall extremism (max of all dimensions)
        all_scores = [overall_categorized_scores[dim]['score'] for dim in overall_categorized_scores]
        if all_scores:
            overall_extremism_score = max(all_scores)
        else:
            overall_extremism_score = 0.0
        
        overall_extremism_info = categorize_score(overall_extremism_score)
        overall_categorized_scores['overall_extremism'] = {
            'score': overall_extremism_score,
            'level': overall_extremism_info['level'],
            'color': overall_extremism_info['color'],
            'icon': overall_extremism_info['icon']
        }
        print(f"  📊 Overall extremism: {overall_extremism_score:.1f} → {overall_extremism_info['level']}")
        
        # Step 7: Save debug JSON
        debug_data = {
            'filename': file.filename,
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'transcription_length': len(transcription_text),
                'sentences_count': len(sentences),
                'flagged_sentences_count': len(flagged_words),
                'overall_extremism_level': overall_extremism_info['level'],
                'overall_extremism_score': overall_extremism_score,
            },
            'transcription_text': transcription_text,
            'flagged_words': flagged_words,
            'overall_scores': overall_categorized_scores,
            'processed_sentences': processed_sentences,
            'batch_results': batch_results,
        }
        
        # Create debug directory
        debug_dir = os.path.join(os.path.dirname(__file__), 'debug_output')
        os.makedirs(debug_dir, exist_ok=True)
        
        timestamp_str = datetime.now().strftime('%Y%m%d_%H%M%S')
        debug_filename = f"analysis_{timestamp_str}.json"
        debug_filepath = os.path.join(debug_dir, debug_filename)
        
        with open(debug_filepath, 'w', encoding='utf-8') as f:
            json.dump(debug_data, f, indent=2, ensure_ascii=False)
        
        print(f"💾 Debug JSON saved: {debug_filepath}")
        
        # Step 8: Return response
        response_data = {
            "transcription": processed_sentences,
            "transcription_text": transcription_text,
            "flagged_words": flagged_words,
            "extremism": {
                "scores": overall_categorized_scores,
                "targets": {},  # Could aggregate from batch results if needed
                "group_mapping": {},
            },
        }
        
        print(f"📤 Response: {len(processed_sentences)} sentences, {len(flagged_words)} flagged sentences")
        
        return JSONResponse(content=response_data)

    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"❌ Processing error: {str(e)}")
        print(f"📋 Details:\n{error_details}")
        raise HTTPException(status_code=500, detail=f"{type(e).__name__}: {e}")

@app.post("/vocabulary-filter/add")
async def add_word_to_filter(request: WordRequest):
    """Add a word to the vocabulary filter"""
    try:
        word = request.word.lower().strip()
        if not word:
            raise HTTPException(status_code=400, detail="Word cannot be empty")
        
        print(f"➕ Adding word to filter: {word}")
        _flagger.add_word(word)
        
        return {
            "success": True,
            "message": f"Word '{word}' added to filter",
            "total_words": len(_flagger.bad_words)
        }
    except Exception as e:
        print(f"❌ Error adding word: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/vocabulary-filter/remove")
async def remove_word_from_filter(request: WordRequest):
    """Remove a word from the vocabulary filter"""
    try:
        word = request.word.lower().strip()
        if not word:
            raise HTTPException(status_code=400, detail="Word cannot be empty")
        
        print(f"➖ Removing word from filter: {word}")
        _flagger.remove_word(word)
        
        return {
            "success": True,
            "message": f"Word '{word}' removed from filter",
            "total_words": len(_flagger.bad_words)
        }
    except Exception as e:
        print(f"❌ Error removing word: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/vocabulary-filter/list")
async def get_filtered_words():
    """Get the list of all filtered words"""
    try:
        if _flagger.bad_words is None:
            print("⚠️ bad_words is None, returning empty list")
            words = []
        else:
            words = sorted(list(_flagger.bad_words))
        print(f"📋 Retrieved {len(words)} filtered words")
        
        return {
            "success": True,
            "words": words,
            "total_words": len(words)
        }
    except Exception as e:
        print(f"❌ Error getting filtered words: {str(e)}")
        # Return empty list instead of error
        return {
            "success": False,
            "words": [],
            "total_words": 0
        }

if __name__ == "__main__":
    import uvicorn
    print("🚀 Starting server...")
    print("📡 API available at: http://localhost:8000")
    print("📖 Documentation: http://localhost:8000/docs")
    uvicorn.run(app, host="0.0.0.0", port=8000)