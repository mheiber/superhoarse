# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Superhoarse is a privacy-focused, local voice-to-text macOS application built with Swift. It uses the Parakeet engine via FluidAudio for real-time speech recognition and features a global hotkey system for seamless text insertion.

## Development Commands

### Building and Running
```bash
# Build release version
swift build -c release
make build

# Run in development mode
swift run
make run

# Clean build artifacts
swift package clean
make clean

# Install to /Applications (requires build first)
make install
```

### Testing
```bash
# Run all tests
swift test

# Run tests with coverage
swift test --enable-code-coverage
./test-coverage.sh

# Run specific test cases
swift test --filter SuperhoarseIntegrationTests
swift test --filter DictationBugReproductionTests
```

## Architecture

### Core Components

**AppState (`Sources/AppState.swift`)** - Central state manager and coordinator
- Manages recording state, transcription flow, and accessibility permissions
- Coordinates between AudioRecorder, ParakeetEngine, and HotKeyManager
- Handles text insertion and clipboard operations
- Uses `@MainActor` for thread safety with UI updates

**ParakeetEngine (`Sources/ParakeetEngine.swift`)** - Speech recognition implementation
- Wraps FluidAudio's AsrManager for local speech transcription
- Converts 16-bit PCM audio data to float arrays for processing
- Implements async initialization pattern with error handling
- Filters short recordings (<0.5s) and silent audio

**AudioRecorder (`Sources/AudioRecorder.swift`)** - Audio capture and processing
- Records 16kHz mono PCM audio optimized for speech recognition
- Provides real-time audio level monitoring for UI feedback
- Handles temporary file creation and cleanup automatically
- Uses AVFoundation with proper microphone permission handling

**HotKeyManager (`Sources/HotKeyManager.swift`)** - Global keyboard shortcuts
- Registers system-wide hotkeys using Carbon framework
- Default: ⌘⇧Space (configurable via UserDefaults)
- Supports multiple modifier combinations (Cmd+Shift, Cmd+Option, etc.)
- Dynamically updates hotkey registration when settings change

**SuperhoarseApp (`Sources/main.swift`)** - App lifecycle and UI
- Menu bar application (no Dock icon) using `.accessory` activation policy
- AppDelegate manages StatusItem, settings window, and listening indicator
- Uses SwiftUI with NSHostingController for cross-framework integration

### Data Flow

1. **User Input**: Global hotkey press detected by HotKeyManager
2. **Recording**: AppState triggers AudioRecorder to capture audio
3. **Processing**: Audio data converted and sent to ParakeetEngine
4. **Output**: Transcribed text inserted at cursor position and copied to clipboard

### Key Dependencies

- **FluidAudio (0.2.0)** - Speech recognition engine interface
- **AVFoundation** - Audio recording and device management  
- **Carbon** - Low-level system access for global hotkeys
- **ApplicationServices** - Accessibility API for text insertion

## Testing Strategy

The codebase includes comprehensive test coverage with several specialized test suites:

- **Integration Tests** - End-to-end workflow testing
- **UI Tests** - SwiftUI component and interaction testing
- **Bug Reproduction Tests** - Specific regression testing for dictation issues
- **User Workflow Tests** - Real-world usage scenario validation

Use `./test-coverage.sh` to generate detailed coverage reports. Tests exclude app lifecycle methods and UI setup that require full macOS app environment.

## Permissions and Security

- **Microphone Access** - Required for audio recording (AVCaptureDevice)
- **Accessibility Access** - Required for text insertion (AXIsProcessTrusted)
- **No Network Access** - All processing occurs locally on device
- Text sanitization prevents injection of control characters and keyboard shortcuts

## Performance Considerations

- Engine initialization occurs asynchronously during app startup
- Audio processing uses 16kHz sample rate optimized for speech recognition
- Temporary audio files are automatically cleaned up after transcription
- Memory usage optimized for Apple Silicon Macs (~100-200MB including models)