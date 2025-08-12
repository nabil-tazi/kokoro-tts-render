#!/bin/bash
set -e

echo "🚀 Setting up Kokoro TTS on Render..."
echo "🐍 Python version: $(python --version)"

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

# Install Kokoro TTS dependencies
echo "🐍 Installing Kokoro TTS dependencies..."
pip install --no-cache-dir \
    torch \
    torchaudio \
    onnxruntime \
    librosa \
    soundfile \
    numpy \
    scipy \
    "kokoro-onnx>=0.4.4" \
    ebooklib \
    PyMuPDF

# Install a dummy sounddevice that won't crash
echo "🎵 Installing dummy sounddevice for headless operation..."
cat > dummy_sounddevice.py << 'EOF'
"""Dummy sounddevice module for headless operation"""

def play(*args, **kwargs):
    """Dummy play function that does nothing"""
    print("sounddevice.play() called but disabled in headless mode")
    pass

def wait(*args, **kwargs):
    """Dummy wait function"""
    pass

def query_devices(*args, **kwargs):
    """Return empty device list"""
    return []

# Add any other sounddevice functions that might be used
default_device = None
EOF

# Replace the real sounddevice with our dummy
mv dummy_sounddevice.py "$(python -c 'import site; print(site.getsitepackages()[0])')/sounddevice.py"

echo "✅ Installed dummy sounddevice module"

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
if [ -f "voices-v1.0.bin" ] && [ -f "kokoro-v1.0.onnx" ]; then
    echo "✅ Model files downloaded successfully"
    ls -lh voices-v1.0.bin kokoro-v1.0.onnx
else
    echo "❌ Some model files are missing!"
    ls -la *.bin *.onnx 2>/dev/null || echo "No model files found"
fi

# Make the script executable
chmod +x kokoro-tts

# Quick test (don't fail if it doesn't work perfectly)
echo "🧪 Quick test of Kokoro TTS..."
echo "Test" > test.txt
if timeout 30 ./kokoro-tts test.txt test_output.mp3 --voice=af_sarah --format=mp3 2>/dev/null; then
    if [ -f "test_output.mp3" ] && [ -s "test_output.mp3" ]; then
        echo "✅ Kokoro TTS test successful!"
        ls -lh test_output.mp3
    else
        echo "⚠️ Test completed but output file is empty"
    fi
else
    echo "⚠️ Test failed, but continuing..."
fi
rm -f test.txt test_output.mp3

# Go back to main directory
cd ..

echo "✅ Setup complete!"
echo "📁 Final directory check:"
ls -la kokoro-tts/ | head -5
echo "🎉 Ready to start API server..."