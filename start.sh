#!/bin/bash
set -e

echo "🚀 Setting up Kokoro TTS on Render..."

# Install system dependencies
echo "📦 Installing system dependencies..."
apt-get update
apt-get install -y wget curl git ffmpeg

# Clone Kokoro TTS repository
echo "📥 Downloading Kokoro TTS..."
if [ ! -d "kokoro-tts" ]; then
    git clone https://github.com/nazdridoy/kokoro-tts.git
    cd kokoro-tts
else
    cd kokoro-tts
    git pull
fi

# Install Python dependencies from Kokoro TTS
echo "🐍 Installing Kokoro TTS Python dependencies..."
pip install -r requirements.txt

# Download model files
echo "🧠 Downloading AI models (this may take a few minutes)..."

# Download voices file (binary format, preferred)
if [ ! -f "voices-v1.0.bin" ]; then
    echo "Downloading voices file..."
    wget -O voices-v1.0.bin https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/voices-v1.0.bin
else
    echo "Voices file already exists"
fi

# Download main model file
if [ ! -f "kokoro-v1.0.onnx" ]; then
    echo "Downloading main model file..."
    wget -O kokoro-v1.0.onnx https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/kokoro-v1.0.onnx
else
    echo "Model file already exists"
fi

# Make the script executable
chmod +x kokoro-tts

# Test that everything works
echo "🧪 Testing Kokoro TTS installation..."
echo "Hello world" > test.txt
./kokoro-tts test.txt test_output.wav --voice=af_sarah
if [ -f "test_output.wav" ]; then
    echo "✅ Kokoro TTS test successful!"
    rm test.txt test_output.wav
else
    echo "❌ Kokoro TTS test failed!"
    exit 1
fi

# Go back to main directory
cd ..

echo "✅ Kokoro TTS setup complete!"
echo "🎉 Ready to start the API server..."