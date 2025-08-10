import Foundation
import FluidAudio

enum ParakeetEngineError: Error {
    case initializationFailed(String)
    case transcriptionFailed(String)
}

@MainActor
class ParakeetEngine: @preconcurrency SpeechRecognitionEngine {
    private var asrManager: AsrManager?
    
    var isInitialized: Bool {
        return asrManager != nil
    }
    
    let engineName = "Parakeet"
    
    init() {
        Task {
            try await initialize()
        }
    }
    
    func initialize() async throws {
        do {
            let config = ASRConfig()
            self.asrManager = AsrManager(config: config)
            
            // Verify the manager was created and is functional
            guard let manager = self.asrManager else {
                throw ParakeetEngineError.initializationFailed("AsrManager creation failed")
            }
            
            // Add a small delay to ensure proper initialization
            try await Task.sleep(for: .milliseconds(100))
            
            // Engine initialized successfully - no logging needed
        } catch {
            print("Parakeet engine initialization failed: \(error)")
            self.asrManager = nil
            throw ParakeetEngineError.initializationFailed("Failed to initialize: \(error)")
        }
    }
    
    func transcribe(_ audioData: Data) async -> String? {
        guard let manager = asrManager else {
            print("Parakeet engine not initialized for transcription")
            return nil
        }
        
        // Convert audio data to float array for Parakeet
        let floatArray = convertAudioDataToFloatArray(audioData)
        
        guard !floatArray.isEmpty else {
            print("Empty audio data for Parakeet transcription")
            return nil
        }
        
        // Skip very short recordings (less than 0.5 seconds at 16kHz)
        let minimumSamples = 8000  // 0.5 seconds at 16kHz
        if floatArray.count < minimumSamples {
            return nil
        }
        
        // Check for mostly silent audio
        let rmsLevel = sqrt(floatArray.map { $0 * $0 }.reduce(0, +) / Float(floatArray.count))
        if rmsLevel < 0.01 {
            return nil
        }
        
        do {
            let result = try await manager.transcribe(floatArray)
            let finalResult = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return finalResult.isEmpty ? nil : finalResult
        } catch {
            print("Parakeet transcription failed: \(error)")
            // If transcription fails due to engine issues, mark as uninitialized so it can be recreated
            if error.localizedDescription.contains("notInitialized") {
                print("Marking Parakeet engine as uninitialized due to error")
                self.asrManager = nil
            }
            return nil
        }
    }
    
    private func convertAudioDataToFloatArray(_ data: Data) -> [Float] {
        // Convert 16-bit PCM to float array
        let int16Array = data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Int16.self))
        }
        
        return int16Array.map { Float($0) / Float(Int16.max) }
    }
}