from fastapi.testclient import TestClient
import sys
import os

# Ensure the project root is on sys.path: .../PycharmProjects/Junction_2025_Delft/
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# Import the FastAPI app from the src package
from src.backend.request_handler import app

client = TestClient(app)

def test_process_media(file_path: str) -> None:
    with open(file_path, "rb") as f:
        files = {"file": (os.path.basename(file_path), f, "video/mp4")}
        response = client.post("/process-media/", files=files)
    print("Status code:", response.status_code)
    print("Response JSON:", response.json())

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python -m example.test_puzzles_together <audio_or_video_file>")
        sys.exit(1)
    test_process_media(sys.argv[1])
