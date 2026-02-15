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

### Model Management
```bash
# Automatic (happens during build if needed)
make build  # Auto-downloads models if missing

# Manual update to latest models
make update-models

# Quick validation (fast, uses marker)
make check-models

# Full validation (slow, re-hashes all files)
make models
```

**Models:**
- Location: `Sources/Resources/` (gitignored, ~607MB)
- Version tracking: `.models_version` marker file (local cache)
- Checksums: `models.sha256` (committed to git for reproducibility)
- Source: HuggingFace parakeet-tdt-0.6b-v2-coreml
- First build auto-downloads if missing

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
- Handles BOTH key-down (`kEventHotKeyPressed`) AND key-up (`kEventHotKeyReleased`) events
- Supports two configurable trigger keys: TRIGGER KEY (toggle) and TRIGGER PUSH-TO-TALK (PTT)
- When both keys are the same (default), registers one Carbon hotkey with `.shared` identity
- When keys differ, registers two separate Carbon hotkeys with `.toggle` and `.ptt` identities
- Default: ⌘⇧Space for both (configurable via UserDefaults)
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

## User flows

- Remember to always update @user_flows.md When we make a change that affects user workflows.

## Push-to-Talk / Hold-to-Record Architecture

**IMPORTANT: Read this before modifying the hotkey or recording logic.**

The app supports two recording modes using the same or different hotkeys:

### How it works

1. **Hold-to-record (PTT)**: Hold the hotkey while speaking. Release to stop and transcribe.
2. **Tap-to-toggle**: Quick-press the hotkey to start recording. Press again to stop.

### Same key for both (default behavior)

When TRIGGER KEY and TRIGGER PUSH-TO-TALK are the same (the default), the app uses
**timing-based disambiguation** on key-up:

- Key-down → start recording immediately
- Key-up after **< 200ms** → this was a **tap** → stay recording, enter toggle mode
- Key-up after **>= 200ms** → this was a **hold** → stop recording, transcribe

The 200ms threshold comes from whisper.cpp's `talk.cpp` reference implementation.
A normal intentional tap is 100-150ms. Holding to say even a short word ("yes") takes 400ms+.

### Different keys (no ambiguity)

When the user sets different keys for toggle vs PTT in settings, there is no timing
ambiguity. The toggle key always toggles. The PTT key always holds.

### Escape key behavior

- **During hold** (key physically down): ESC is NOT monitored. The user's hand is
  on the hotkey and can't easily reach ESC.
- **During toggle mode** (after a tap): ESC IS monitored and cancels recording.
  Both hands are free.

### Listening indicator instructions

The floating listening indicator shows different instructions depending on mode:
- Hold mode: "Release ⌘⇧Space to stop" (no ESC instruction)
- Toggle mode: "ESC to cancel" + "⌘⇧Space to stop"

### Key files

- `Sources/HotKeyManager.swift` — Carbon event registration, key-down/key-up dispatch
- `Sources/AppState.swift` — Smart hold/toggle logic, 200ms threshold, recording state
- `Sources/ContentView.swift` — Listening indicator UI, settings UI for both trigger keys

### UserDefaults keys for hotkeys

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `hotKeyModifier` | Int | 0 | Modifier combo (shared by both keys) |
| `hotKeyCode` | Int | 49 | Toggle trigger key (Carbon key code) |
| `hotKeyCodePTT` | Int | 0 | PTT trigger key (0 = use same as hotKeyCode) |

### Common pitfalls

- **Don't remove key-up handling** from HotKeyManager. It's essential for PTT.
- **Don't start ESC monitoring during hold mode**. User can't reach ESC while holding.
- **The 200ms threshold is intentional**. Don't change it without testing both modes.
- **hotKeyCodePTT == 0 means "same as toggle key"**, not "no PTT key". This is how
  UserDefaults works (returns 0 for unset integers).
