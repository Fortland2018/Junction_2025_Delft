from fastapi.testclient import TestClient
import sys
import os

# Import the FastAPI app
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src', 'backend')))
from request_handler import app

client = TestClient(app)

def test_process_media(file_path):
    with open(file_path, "rb") as f:
        files = {"file": (os.path.basename(file_path), f, "application/octet-stream")}
        response = client.post("/process-media/", files=files)
    print("Status code:", response.status_code)
    print("Response JSON:", response.json())

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python test_puzzles_together.py <audio_or_video_file>")
        sys.exit(1)
    test_process_media(sys.argv[1])

