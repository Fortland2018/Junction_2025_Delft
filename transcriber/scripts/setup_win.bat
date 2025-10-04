@echo off
REM --- Ensure Python 3.11 is installed (https://www.python.org/downloads/windows/) ---
where py >nul 2>&1 || (echo Python launcher not found. Install Python 3.11 first. & exit /b 1)

REM --- Create virtualenv with Python 3.11 ---
py -3.11 -m venv .venv || (echo Failed to create venv with Python 3.11 & exit /b 1)
call .venv\Scripts\activate

REM --- Upgrade pip and install deps ---
python -m pip install --upgrade pip
pip install -r transcriber\requirements.txt

REM --- Ensure FFmpeg exists (winget path shown; if you use Chocolatey: choco install ffmpeg) ---
where ffmpeg >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
  echo FFmpeg not found on PATH. Installing via winget...
  winget install --id Gyan.FFmpeg -e --source winget
)

echo.
ffmpeg -version || (echo FFmpeg still not found. Add its bin folder to PATH and re-run. & exit /b 1)
echo Setup complete. To activate later: call .venv\Scripts\activate
