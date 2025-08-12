#!/usr/bin/env python3
"""
Kokoro TTS API for Render deployment
Simple FastAPI service that wraps Kokoro TTS
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel
import subprocess
import os
import tempfile
import uuid
from pathlib import Path
import logging
import asyncio
from typing import Optional
import uvicorn

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Kokoro TTS API",
    description="High-quality text-to-speech using Kokoro TTS",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Data models
class TTSRequest(BaseModel):
    text: str
    voice: str = "af_sarah"
    speed: float = 1.0
    format: str = "mp3"

class TTSResponse(BaseModel):
    success: bool
    message: str
    audio_url: Optional[str] = None
    error: Optional[str] = None

# Global variables
KOKORO_PATH = Path("/opt/render/project/src/kokoro-tts")
OUTPUT_DIR = Path("/tmp/tts_output")
OUTPUT_DIR.mkdir(exist_ok=True)

@app.on_startup
async def startup_event():
    """Check if Kokoro TTS is properly installed"""
    logger.info("Starting Kokoro TTS API...")
    
    # Check if kokoro-tts script exists
    kokoro_script = KOKORO_PATH / "kokoro-tts"
    if kokoro_script.exists():
        logger.info("✅ Kokoro TTS script found")
    else:
        logger.warning("⚠️ Kokoro TTS script not found, will try current directory")
    
    # Check for model files
    model_file = KOKORO_PATH / "kokoro-v1.0.onnx"
    voices_file = KOKORO_PATH / "voices-v1.0.bin"
    
    if model_file.exists():
        logger.info("✅ Model file found")
    else:
        logger.warning("⚠️ Model file not found in expected location")
        
    if voices_file.exists():
        logger.info("✅ Voices file found")
    else:
        logger.warning("⚠️ Voices file not found in expected location")

def find_kokoro_script():
    """Find the kokoro-tts script in various possible locations"""
    possible_paths = [
        Path("/opt/render/project/src/kokoro-tts"),
        Path("/opt/render/project/src"),
        Path("."),
        Path("./kokoro-tts"),
    ]
    
    for path in possible_paths:
        script_path = path / "kokoro-tts"
        if script_path.exists():
            return script_path
    
    return None

def run_kokoro_tts(text: str, voice: str, speed: float, output_format: str) -> tuple[bool, str, Optional[str]]:
    """
    Run Kokoro TTS and return success status, message, and output file path
    """
    try:
        # Find the kokoro script
        kokoro_script = find_kokoro_script()
        if not kokoro_script:
            return False, "Kokoro TTS script not found", None
        
        # Create temp input file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write(text)
            input_file = f.name
        
        # Create output file path
        output_filename = f"tts_{uuid.uuid4().hex[:8]}.{output_format}"
        output_file = OUTPUT_DIR / output_filename
        
        # Prepare command
        cmd = [
            str(kokoro_script),
            input_file,
            str(output_file),
            f"--voice={voice}",
            f"--speed={speed}",
            f"--format={output_format}"
        ]
        
        logger.info(f"Running: {' '.join(cmd)}")
        
        # Run the command with timeout
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,  # 2 minutes timeout
            cwd=kokoro_script.parent
        )
        
        # Clean up input file
        os.unlink(input_file)
        
        if result.returncode == 0:
            if output_file.exists():
                logger.info(f"✅ TTS generation successful: {output_file}")
                return True, "TTS generation successful", str(output_file)
            else:
                logger.error("TTS command succeeded but output file not found")
                return False, "Output file not created", None
        else:
            logger.error(f"TTS command failed: {result.stderr}")
            return False, f"TTS generation failed: {result.stderr}", None
            
    except subprocess.TimeoutExpired:
        logger.error("TTS generation timed out")
        return False, "TTS generation timed out", None
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return False, f"Unexpected error: {str(e)}", None

@app.get("/")
async def root():
    """Root endpoint with basic info"""
    return {
        "service": "Kokoro TTS API",
        "status": "running",
        "endpoints": {
            "generate": "POST /generate",
            "voices": "GET /voices",
            "health": "GET /health"
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    kokoro_script = find_kokoro_script()
    return {
        "status": "healthy",
        "kokoro_available": kokoro_script is not None,
        "script_path": str(kokoro_script) if kokoro_script else None
    }

@app.post("/generate")
async def generate_speech(request: TTSRequest):
    """Generate speech from text"""
    try:
        # Validate input
        if not request.text.strip():
            raise HTTPException(status_code=400, detail="Text cannot be empty")
        
        if len(request.text) > 5000:
            raise HTTPException(status_code=400, detail="Text too long (max 5000 characters)")
        
        # Generate speech
        success, message, output_file = run_kokoro_tts(
            text=request.text,
            voice=request.voice,
            speed=request.speed,
            output_format=request.format
        )
        
        if success and output_file:
            # Return the audio file directly
            filename = Path(output_file).name
            return FileResponse(
                path=output_file,
                media_type="audio/mpeg" if request.format == "mp3" else "audio/wav",
                filename=filename
            )
        else:
            raise HTTPException(status_code=500, detail=message)
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in generate_speech: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/voices")
async def list_voices():
    """List available voices"""
    voices = {
        "en-us": {
            "female": ["af_sarah", "af_nova", "af_alloy", "af_echo"],
            "male": ["am_adam", "am_onyx", "am_fable"]
        },
        "en-gb": {
            "female": ["bf_emma", "bf_charlotte"],
            "male": ["bm_brian", "bm_daniel"]
        },
        "ja": {
            "female": ["jf_alpha"],
            "male": ["jm_kumo"]
        }
    }
    return {
        "voices": voices,
        "default": "af_sarah",
        "note": "Use voice codes like 'af_sarah' in your requests"
    }

# Run the app
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=port,
        log_level="info"
    )