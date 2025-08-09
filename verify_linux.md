# SuperWhisper Lite Linux Configuration

## Changes Made for Linux Support

1. **Package.swift Updates:**
   - Added Linux platform support (`.linux`)
   - Using `whisper.spm` package which supports Linux
   - Updated dependencies to use the official whisper.spm package

2. **SpeechRecognizer.swift Updates:**
   - Added platform-specific path handling for Linux
   - On Linux: Uses `~/.local/share/SuperWhisperLite/Models`
   - On macOS: Uses standard Application Support directory

## Building on Linux

To build this project on Linux, you'll need:

1. **Install Swift for Linux:**
   ```bash
   # Download Swift for your Ubuntu version and architecture
   wget https://download.swift.org/swift-6.0.2-release/ubuntu2404-aarch64/swift-6.0.2-RELEASE/swift-6.0.2-RELEASE-ubuntu24.04-aarch64.tar.gz
   
   # Extract and add to PATH
   tar xzf swift-6.0.2-RELEASE-ubuntu24.04-aarch64.tar.gz
   export PATH="/path/to/swift-6.0.2-RELEASE-ubuntu24.04-aarch64/usr/bin:$PATH"
   ```

2. **Build the project:**
   ```bash
   swift build
   ```

3. **Run the project:**
   ```bash
   swift run
   ```

## Key Features Working on Linux:

- ✅ Cross-platform file path handling
- ✅ Whisper model download and caching
- ✅ SHA-256 integrity verification
- ✅ Audio transcription using whisper.cpp
- ✅ Platform-specific directory creation

## Runtime Requirements:

- Swift 5.9 or later
- Linux with glibc support
- Internet connection for initial model download
- Audio input capabilities