#!/bin/bash
set -e

echo "🚀 Setting up Kokoro TTS on Render..."

# Skip apt-get operations on Render (they're not allowed)
echo "📦 Skipping system package installation (using Render's base image)..."

# Install our API dependencies first (minimal set)
echo "🐍 Installing API server dependencies..."
pip install --no-cache-dir fastapi uvicorn[standard] python-multipart pydantic requests

# Clone Kokoro TTS repository
echo "📥 Downloading Kokoro TTS..."
if [ ! -d "kokoro-tts" ]; then
    git clone https://github.com/nazdridoy/kokoro-tts.git
    cd kokoro-tts
else
    cd kokoro-tts
    git pull
fi

# Install Kokoro TTS dependencies (let it handle its own versions)
echo "🐍 Installing Kokoro TTS dependencies..."
if [ -f "requirements.txt" ]; then
    pip install --no-cache-dir -r requirements.txt
else
    echo "No requirements.txt found in kokoro-tts, installing manually..."
    pip install --no-cache-dir torch torchaudio onnxruntime librosa soundfile numpy scipy
fi

# Download model files
echo "🧠 Downloading AI models (this may take a few minutes)..."

# Download voices file (binary format, preferred)
if [ ! -f "voices-v1.0.bin" ]; then
    echo "Downloading voices file..."
    curl -L -o voices-v1.0.bin https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/voices-v1.0.bin
else
    echo "Voices file already exists"
fi

# Download main model file
if [ ! -f "kokoro-v1.0.onnx" ]; then
    echo "Downloading main model file..."
    curl -L -o kokoro-v1.0.onnx https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/kokoro-v1.0.onnx
else
    echo "Model file already exists"
fi

# Verify model files were downloaded
echo "📋 Checking downloaded files..."
ls -lh voices-v1.0.bin kokoro-v1.0.onnx 2>/dev/null || echo "Some model files missing!"

# Make the script executable
chmod +x kokoro-tts

# Quick test (don't fail if it doesn't work perfectly)
echo "🧪 Testing Kokoro TTS installation..."
echo "Hello world" > test.txt
if ./kokoro-tts test.txt test_output.wav --voice=af_sarah --format=wav 2>/dev/null; then
    if [ -f "test_output.wav" ]; then
        echo "✅ Kokoro TTS test successful!"
        rm -f test.txt test_output.wav
    else
        echo "⚠️ Test ran but no output file"
    fi
else
    echo "⚠️ Test had issues, but API server will try anyway"
fi
rm -f test.txt test_output.wav

# Go back to main directory
cd ..

echo "✅ Setup complete!"
echo "📁 Directory structure:"
ls -la kokoro-tts/ | head -10
echo "🎉 Setup finished, ready for app start..."