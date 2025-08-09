# Plan: Add Optional Parakeet Engine to Superhoarse

Based on your current Superhoarse architecture and the success of SuperWhisper's Parakeet implementation, here's my plan:

## 1. Add Speech Engine Abstraction Layer
- Create `SpeechRecognitionEngine` protocol 
- Refactor existing `SpeechRecognizer` to conform to protocol as `WhisperEngine`
- Implement `ParakeetEngine` using FluidAudio (more mature than swift-parakeet-mlx)

## 2. Integrate FluidAudio for Parakeet
- Add FluidAudio via Swift Package Manager 
- FluidAudio provides Parakeet TDT-0.6b with CoreML optimization
- Matches your privacy-first approach (fully local processing)

## 3. Update Settings UI  
- Add engine picker to existing `KeyboardShortcutConfigView`
- Options: "Whisper (Default)" and "Parakeet (Faster)"
- Store engine preference in `@AppStorage`

## 4. Modify AppState Architecture
- Add `speechEngine` property to switch between engines
- Update `processAudio()` to use selected engine
- Maintain backward compatibility with existing Whisper setup

## 5. Performance & UX Improvements
- Show engine status in UI ("Using Parakeet" vs "Using Whisper")  
- Handle model downloading/initialization for both engines
- Add fallback to Whisper if Parakeet fails

This approach maintains your existing Whisper implementation while adding Parakeet as an optional faster engine, similar to how SuperWhisper implements it.

## Research Findings

### SuperWhisper's Success with Parakeet
- SuperWhisper users report Parakeet is "fucking awesome"
- Faster and more accurate than Whisper for many use cases
- MacWhisper also added Parakeet support with great results

### Technical Options Found
1. **FluidAudio** (Recommended)
   - Fully Native Swift and CoreML
   - Parakeet TDT-0.6b model with Token Duration Transducer
   - Real-time processing optimized for Apple Silicon
   - Active development, proper Swift Package Manager integration

2. **swift-parakeet-mlx** (Alternative)
   - Direct MLX Swift implementation
   - Being archived by FluidInference in favor of FluidAudio
   - Requires Xcode build (Metal shader compilation issues with SwiftPM)

### Why FluidAudio Over swift-parakeet-mlx
- More mature and actively maintained
- CoreML backend is more stable than raw MLX
- Better integration with existing Swift codebases
- FluidInference team specifically recommends it over their MLX implementation

## Implementation Strategy

### Phase 1: Engine Abstraction
```swift
protocol SpeechRecognitionEngine {
    func transcribe(_ audioData: Data, completion: @escaping (String?) -> Void)
    var isInitialized: Bool { get }
    func initialize() async throws
}
```

### Phase 2: FluidAudio Integration
- Add dependency to Package.swift
- Implement ParakeetEngine conforming to protocol
- Handle model downloading and initialization

### Phase 3: UI Updates
- Extend settings with engine selection
- Add status indicators
- Maintain clean, minimal UI design

### Phase 4: Testing & Fallbacks
- Test both engines thoroughly
- Implement graceful fallbacks
- Performance comparison and optimization

This plan leverages the proven success of Parakeet in similar apps while maintaining Superhoarse's privacy-first, lightweight architecture.