#!/bin/bash
# Setup script for FFmpeg Whisper Filter
set -e

echo "🎙️  FFmpeg Whisper Filter Setup"
echo "================================"
echo ""

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    NCPU=$(sysctl -n hw.ncpu)
    LIB_EXT="dylib"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    NCPU=$(nproc)
    LIB_EXT="so"
else
    echo "❌ Unsupported OS: $OSTYPE"
    exit 1
fi

echo "📋 Detected OS: $OS"
echo "🖥️  CPU cores: $NCPU"
echo ""

# Check dependencies
echo "🔍 Checking dependencies..."
command -v git >/dev/null 2>&1 || { echo "❌ git not found"; exit 1; }
command -v make >/dev/null 2>&1 || { echo "❌ make not found"; exit 1; }
command -v cmake >/dev/null 2>&1 || { echo "❌ cmake not found"; exit 1; }
echo "✅ Dependencies OK"
echo ""

# Clone and build whisper.cpp
WHISPER_DIR="/tmp/whisper.cpp"
if [ ! -d "$WHISPER_DIR" ]; then
    echo "📥 Cloning whisper.cpp..."
    git clone https://github.com/ggerganov/whisper.cpp "$WHISPER_DIR"
else
    echo "📂 whisper.cpp already cloned"
fi

cd "$WHISPER_DIR"

echo "🔨 Building whisper.cpp..."
if [[ "$OS" == "macos" ]]; then
    # Build with Metal support on macOS
    make clean
    make WHISPER_METAL=1 -j$NCPU
elif [[ "$OS" == "linux" ]]; then
    # Check for CUDA
    if command -v nvcc >/dev/null 2>&1; then
        echo "🎮 CUDA detected, building with GPU support..."
        make clean
        make WHISPER_CUBLAS=1 -j$NCPU
    else
        echo "💻 Building CPU-only version..."
        make clean
        make -j$NCPU
    fi
fi

echo "📦 Installing whisper.cpp library..."
if [[ "$OS" == "macos" ]]; then
    sudo cp libwhisper.$LIB_EXT /usr/local/lib/ 2>/dev/null || \
        cp libwhisper.$LIB_EXT ~/lib/
    sudo cp *.h /usr/local/include/ 2>/dev/null || \
        cp *.h ~/include/
elif [[ "$OS" == "linux" ]]; then
    sudo cp libwhisper.$LIB_EXT /usr/local/lib/
    sudo cp *.h /usr/local/include/
    sudo ldconfig
fi

echo "✅ whisper.cpp installed"
echo ""

# Download models
echo "📥 Downloading Whisper models..."
cd "$WHISPER_DIR/models"

if [ ! -f "ggml-base.bin" ]; then
    echo "⬇️  Downloading base model (~150MB)..."
    bash ./download-ggml-model.sh base
else
    echo "✅ Base model already downloaded"
fi

if [ ! -f "ggml-tiny.bin" ]; then
    echo "⬇️  Downloading tiny model (~75MB)..."
    bash ./download-ggml-model.sh tiny
else
    echo "✅ Tiny model already downloaded"
fi

MODEL_PATH="$WHISPER_DIR/models"
echo ""
echo "📍 Models installed at: $MODEL_PATH"
echo ""

# Configure FFmpeg
cd /Users/yarontorbaty/Documents/Code/ffmpeg-auto-caption

echo "⚙️  Configuring FFmpeg..."
./configure \
  --enable-gpl \
  --enable-version3 \
  --enable-filter=whisper \
  --extra-cflags="-I/usr/local/include" \
  --extra-ldflags="-L/usr/local/lib" \
  --extra-libs="-lwhisper -lm" \
  --prefix=$HOME/ffmpeg-whisper

echo "✅ Configuration complete"
echo ""

echo "🔨 Building FFmpeg (this may take 10-30 minutes)..."
make -j$NCPU

echo ""
echo "✅ Build complete!"
echo ""
echo "📖 Quick Start:"
echo "==============="
echo ""
echo "1. Test the build:"
echo "   ./ffmpeg -version | grep whisper"
echo ""
echo "2. Generate subtitles:"
echo "   ./ffmpeg -i video.mp4 \\"
echo "     -af \"whisper=model=$MODEL_PATH/ggml-base.bin:destination=subtitles.srt:format=srt\" \\"
echo "     -f null -"
echo ""
echo "3. Install (optional):"
echo "   make install"
echo ""
echo "📚 Full documentation: WHISPER_FILTER_GUIDE.md"
echo ""
echo "🎉 Setup complete!"
