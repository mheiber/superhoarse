# Superhoarse

A lightweight, privacy-focused voice-to-text app for macOS inspired by SuperWhisper. Built with Swift and powered by local AI models for completely offline transcription.

## Features

- **🎤 Global Hotkey Recording** - Press `⌘⇧Space` to start/stop recording from anywhere
- **🤖 Local AI Processing** - Uses OpenAI's Whisper model running entirely on your Mac
- **🔒 Privacy First** - No data leaves your device, all processing is local
- **⚡ Fast & Lightweight** - Optimized for Apple Silicon Macs
- **📋 Smart Text Insertion** - Automatically inserts transcribed text where your cursor is
- **🎯 Simple & Elegant** - Clean SwiftUI interface, minimal configuration needed

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon Mac (M1/M2/M3) recommended for best performance
- Microphone access permission

## Installation

### Option 1: Build from Source

```bash
# Clone the repository
git clone <repository-url>
cd Superhoarse

# Build and install
make build
make install
```

### Option 2: Manual Build

```bash
# Build with Swift Package Manager
swift build -c release

# Create app bundle manually
mkdir -p Superhoarse.app/Contents/MacOS
mkdir -p Superhoarse.app/Contents/Resources
cp .build/release/Superhoarse Superhoarse.app/Contents/MacOS/
cp Sources/Info.plist Superhoarse.app/Contents/

# Move to Applications
cp -R Superhoarse.app /Applications/
```

## Usage

1. **Launch** the app - It will appear in your menu bar
2. **Grant permissions** when prompted:
   - Microphone access for recording
   - Accessibility access for text insertion
3. **Start recording** - Press `⌘⇧Space` anywhere on your Mac
4. **Speak clearly** - The recording indicator will show in the app
5. **Stop recording** - Press `⌘⇧Space` again
6. **Get results** - Transcribed text appears where your cursor was

## Architecture

Superhoarse is built with simplicity and performance in mind:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   SwiftUI App   │────│   App State      │────│  HotKey Manager │
│                 │    │                  │    │                 │
│ - Recording UI  │    │ - Coordinates    │    │ - Global ⌘⇧⎵    │
│ - Status Window │    │   all components │    │ - Carbon Events │
│ - Settings      │    │ - State Updates  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                 ┌──────────────┼──────────────┐
                 │              │              │
        ┌────────▼────────┐    ┌▼──────────────▼┐
        │ Audio Recorder  │    │ Speech         │
        │                 │    │ Recognizer     │
        │ - AVFoundation  │    │                │
        │ - 16kHz PCM     │    │ - whisper.cpp  │
        │ - Temp files    │    │ - Local models │
        └─────────────────┘    └────────────────┘
```

## Dependencies & Justifications

### Core Dependencies

- **whisper.spm** (`~1.5.4`) - Swift Package Manager wrapper for whisper.cpp
  - *Why chosen*: Most efficient C++ implementation of OpenAI's Whisper model
  - *Alternatives considered*: Core ML Whisper (larger), SpeechRecognizer (cloud-based)
  - *Benefits*: Runs entirely offline, optimized for Apple Silicon, smaller memory footprint

### System Frameworks

- **SwiftUI** - Modern declarative UI framework
  - *Why chosen*: Native performance, minimal code, automatic dark mode support
  - *Alternative*: AppKit (more verbose, procedural)

- **AVFoundation** - Audio recording and processing
  - *Why chosen*: Native macOS audio framework with hardware optimization
  - *Alternative*: Third-party audio libraries (unnecessary complexity)

- **Carbon** - Low-level system access for global hotkeys
  - *Why chosen*: Only way to register system-wide keyboard shortcuts on macOS
  - *Alternative*: None for global hotkeys

### Model Selection

- **Whisper Base Model** (74MB) - Balanced speed/accuracy for MVP
  - *Why chosen*: Good accuracy while maintaining fast transcription on Apple Silicon
  - *Alternatives*: Tiny (faster, less accurate), Small (slower, more accurate)
  - *Trade-offs*: Base model provides best balance for real-time usage

## Development

```bash
# Run in development mode
make run

# Clean build artifacts  
make clean

# Set up development environment
make setup
```

## Permissions Required

- **Microphone Access** - Required to record audio for transcription
- **Accessibility Access** - Required to insert text at cursor position
- **Network Access** - Only used once to download the Whisper model (~74MB)

## Performance

- **Cold Start**: ~2-3 seconds (model loading)
- **Recording**: Real-time, minimal CPU usage
- **Transcription**: ~0.5-2x real-time speed (depends on Mac model)
- **Memory Usage**: ~100-200MB (including model)
- **Storage**: ~74MB (Whisper base model)

## Privacy & Security

- ✅ **No telemetry or analytics**
- ✅ **No network requests after initial model download**
- ✅ **All processing happens locally on your Mac**
- ✅ **Audio recordings are temporary and deleted immediately**
- ✅ **No user data is stored or transmitted**

## Limitations

- **macOS only** - Built specifically for Apple's ecosystem
- **English only** - MVP focuses on English transcription (easily expandable)
- **Apple Silicon optimized** - Will work on Intel Macs but slower
- **Base model accuracy** - Good for general use, not specialized terminology

## Roadmap

- [ ] Support for additional languages
- [ ] Configurable hotkey combinations
- [ ] Custom wake words
- [ ] Background app mode
- [ ] Text formatting options
- [ ] Export transcription history

## Contributing

This project prioritizes simplicity and elegance. When contributing:

1. **Keep it simple** - Favor readable code over clever optimizations
2. **Minimal dependencies** - Only add dependencies that provide substantial value
3. **Privacy first** - No features that compromise local-only processing
4. **Performance matters** - Optimize for Apple Silicon architecture

## License

MIT License - see LICENSE file for details

## Credits

- Inspired by [SuperWhisper](https://superwhisper.com/) by Neil Chudleigh
- Built with [whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov
- Uses OpenAI's [Whisper](https://github.com/openai/whisper) models