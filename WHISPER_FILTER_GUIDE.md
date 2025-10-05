# FFmpeg Whisper Filter Development Guide

## Overview

This FFmpeg fork includes an AI-powered automatic captioning feature using whisper.cpp. The filter can transcribe audio from files and live streams in real-time.

## Current Implementation

### Features
- ✅ Real-time audio transcription using whisper.cpp
- ✅ Multiple output formats (SRT, JSON, plain text)
- ✅ GPU acceleration support
- ✅ Voice Activity Detection (VAD) for efficient processing
- ✅ Language auto-detection and manual selection
- ✅ Direct subtitle file output
- ✅ Frame metadata embedding

### Architecture

The implementation is in `libavfilter/af_whisper.c` and works as an audio filter that:
1. Buffers incoming audio samples
2. Processes them through whisper.cpp when buffer is full or VAD detects speech
3. Outputs transcribed text to file or frame metadata
4. Passes audio through unchanged (metadata-only filter)

## Build Instructions

### 1. Install Dependencies

#### whisper.cpp
```bash
# Clone whisper.cpp
cd /tmp
git clone https://github.com/ggerganov/whisper.cpp
cd whisper.cpp

# Build with GPU support (optional)
make WHISPER_CUBLAS=1  # For NVIDIA GPUs
# or
make WHISPER_METAL=1   # For Apple Silicon

# Install library
sudo cp libwhisper.so /usr/local/lib/  # Linux
# or
sudo cp libwhisper.dylib /usr/local/lib/  # macOS

sudo cp ggml-*.h whisper.h /usr/local/include/
sudo ldconfig  # Linux only
```

#### Download Whisper Models
```bash
cd /tmp/whisper.cpp
bash ./models/download-ggml-model.sh base    # ~150MB, good balance
# or
bash ./models/download-ggml-model.sh small   # ~500MB, better accuracy
# or
bash ./models/download-ggml-model.sh tiny    # ~75MB, faster but less accurate

# Models will be in: models/ggml-{model}.bin
```

### 2. Configure FFmpeg

```bash
cd /Users/yarontorbaty/Documents/Code/ffmpeg-auto-caption

# Configure with whisper support
./configure \
  --enable-gpl \
  --enable-version3 \
  --enable-nonfree \
  --enable-filter=whisper \
  --extra-cflags="-I/usr/local/include" \
  --extra-ldflags="-L/usr/local/lib" \
  --extra-libs="-lwhisper -lm"

# For GPU support, add:
# --enable-cuda-nvcc  # NVIDIA
# or configure will auto-detect Metal on macOS
```

### 3. Build FFmpeg

```bash
make -j$(nproc)  # Linux
# or
make -j$(sysctl -n hw.ncpu)  # macOS

# Optional: Install
sudo make install
```

## Usage Examples

### Basic Transcription to SRT

```bash
ffmpeg -i input.mp4 \
  -af "whisper=model=/path/to/ggml-base.bin:destination=subtitles.srt:format=srt" \
  -c copy output.mp4
```

### Live Stream Transcription

```bash
ffmpeg -i rtmp://live.example.com/stream \
  -af "whisper=model=/tmp/whisper.cpp/models/ggml-base.bin:language=en:use_gpu=1:destination=live_captions.srt:format=srt" \
  -c copy output.mp4
```

### JSON Output with VAD

```bash
ffmpeg -i podcast.mp3 \
  -af "whisper=model=/path/to/ggml-base.bin:vad_model=/path/to/ggml-vad.bin:format=json:destination=transcript.json" \
  -f null -
```

### Burn Subtitles Into Video

```bash
# First pass: Generate SRT
ffmpeg -i input.mp4 \
  -af "whisper=model=/path/to/ggml-base.bin:destination=subs.srt:format=srt" \
  -f null -

# Second pass: Burn subtitles
ffmpeg -i input.mp4 \
  -vf "subtitles=subs.srt" \
  output_with_subs.mp4
```

### Multiple Languages

```bash
# Auto-detect language
ffmpeg -i video.mp4 \
  -af "whisper=model=/path/to/ggml-base.bin:language=auto:destination=out.srt:format=srt" \
  -f null -

# Specific language
ffmpeg -i video.mp4 \
  -af "whisper=model=/path/to/ggml-base.bin:language=es:destination=spanish.srt:format=srt" \
  -f null -
```

## Filter Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `model` | string | required | Path to whisper.cpp GGML model file |
| `language` | string | "auto" | Language code (e.g., "en", "es", "fr") or "auto" |
| `queue` | duration | 3000000 | Audio buffer size in microseconds (3 seconds) |
| `use_gpu` | bool | 1 | Enable GPU acceleration |
| `gpu_device` | int | 0 | GPU device index |
| `destination` | string | "" | Output file path (empty for metadata only) |
| `format` | string | "text" | Output format: text, srt, json |
| `vad_model` | string | - | Path to VAD model for voice activity detection |
| `vad_threshold` | float | 0.5 | VAD detection threshold (0.0-1.0) |
| `vad_min_speech_duration` | duration | 100000 | Minimum speech duration in microseconds |
| `vad_min_silence_duration` | duration | 500000 | Minimum silence duration in microseconds |

## Recommended Improvements

### Priority 1: Core Functionality
- [ ] Add WebVTT format support (currently has SRT and JSON)
- [ ] Implement subtitle stream output (not just file output)
- [ ] Add word-level timestamps option
- [ ] Implement translation support (Whisper can translate to English)

### Priority 2: Performance
- [ ] Add multi-stream support (handle multiple audio tracks)
- [ ] Implement streaming output for live captioning
- [ ] Optimize buffer management for lower latency
- [ ] Add benchmark/profiling options

### Priority 3: User Experience
- [ ] Add model auto-download capability
- [ ] Implement confidence scores in output
- [ ] Add progress reporting
- [ ] Create preset configurations for common use cases

### Priority 4: Advanced Features
- [ ] Speaker diarization support
- [ ] Custom vocabulary/prompts
- [ ] Punctuation and formatting options
- [ ] Integration with subtitle formatting libraries

## Testing

### Unit Tests
```bash
# Create test script
cat > test_whisper.sh << 'EOF'
#!/bin/bash
set -e

# Generate test audio
ffmpeg -f lavfi -i "sine=frequency=1000:duration=5" -ac 1 test_audio.wav

# Test basic transcription
./ffmpeg -i test_audio.wav \
  -af "whisper=model=/path/to/model.bin:destination=test.srt:format=srt" \
  -f null -

# Verify output
if [ -f test.srt ]; then
    echo "✓ SRT file generated"
else
    echo "✗ SRT file not found"
    exit 1
fi

# Test JSON output
./ffmpeg -i test_audio.wav \
  -af "whisper=model=/path/to/model.bin:destination=test.json:format=json" \
  -f null -

echo "✓ All tests passed"
EOF

chmod +x test_whisper.sh
./test_whisper.sh
```

## Troubleshooting

### Common Issues

**1. "Failed to initialize whisper context"**
- Verify model path is correct
- Check model file is not corrupted
- Ensure whisper.cpp library is properly installed

**2. "No whisper model path specified"**
- Add `model=/path/to/model.bin` parameter to filter

**3. Slow transcription**
- Enable GPU: `use_gpu=1`
- Use smaller model (tiny or base instead of large)
- Increase queue size to batch more audio

**4. Missing transcription segments**
- Adjust VAD threshold
- Increase buffer queue size
- Check audio quality and volume

## Performance Tips

1. **Model Selection**:
   - `tiny`: Fastest, 75MB, good for real-time on CPU
   - `base`: Good balance, 150MB, recommended for most uses
   - `small`: Better accuracy, 500MB
   - `medium/large`: Best quality, but slower

2. **GPU Acceleration**:
   - Always enable for real-time streaming
   - Can provide 3-10x speedup
   - Required for large models on live streams

3. **Buffer Tuning**:
   - Smaller queue: Lower latency, more API calls
   - Larger queue: Better context, fewer API calls
   - Sweet spot: 2-5 seconds for most content

## Integration Examples

### Web Streaming Platform
```bash
# RTMP input -> HLS output with live captions
ffmpeg -i rtmp://source/stream \
  -af "whisper=model=/path/to/model.bin:language=auto:destination=pipe:1:format=json" \
  -map 0:v -map 0:a \
  -c:v libx264 -c:a aac \
  -f hls -hls_time 2 -hls_list_size 5 \
  stream.m3u8 \
  | python process_captions.py
```

### Video Conference Recording
```bash
ffmpeg -f avfoundation -i ":0" \  # macOS audio input
  -af "whisper=model=/path/to/model.bin:vad_model=/path/to/vad.bin:destination=meeting_transcript.srt:format=srt" \
  recording.mp4
```

### Podcast Processing Pipeline
```bash
#!/bin/bash
# Auto-generate podcast transcripts

for file in podcasts/*.mp3; do
    base=$(basename "$file" .mp3)
    ffmpeg -i "$file" \
      -af "whisper=model=/path/to/model.bin:language=en:destination=transcripts/${base}.json:format=json" \
      -f null -
done
```

## Contributing

Areas where contributions would be valuable:

1. **Additional output formats**: ASS, TTML, etc.
2. **Subtitle styling**: Colors, positioning, fonts
3. **Multi-language detection**: Auto-detect language switches
4. **Performance profiling**: Identify bottlenecks
5. **Documentation**: Usage examples, tutorials
6. **Testing**: Edge cases, stress testing

## Resources

- [whisper.cpp GitHub](https://github.com/ggerganov/whisper.cpp)
- [OpenAI Whisper Paper](https://arxiv.org/abs/2212.04356)
- [FFmpeg Filter Documentation](https://ffmpeg.org/ffmpeg-filters.html)
- [Whisper Model Downloads](https://github.com/ggerganov/whisper.cpp#more-audio-samples)

## License

This filter is part of FFmpeg and follows the same LGPL 2.1+ license.
