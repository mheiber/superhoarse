import Foundation
import FluidAudio

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
        let config = ASRConfig()
        self.asrManager = AsrManager(config: config)
        print("Parakeet engine initialized successfully")
    }
    
    func transcribe(_ audioData: Data) async -> String? {
        guard let manager = asrManager else {
            return nil
        }
        
        // Convert audio data to float array for Parakeet
        let floatArray = convertAudioDataToFloatArray(audioData)
        
        guard !floatArray.isEmpty else {
            return nil
        }
        
        // Skip very short recordings (less than 0.5 seconds at 16kHz)
        let minimumSamples = 8000  // 0.5 seconds at 16kHz
        if floatArray.count < minimumSamples {
            print("Audio too short (\(floatArray.count) samples), skipping transcription")
            return nil
        }
        
        // Check for mostly silent audio
        let rmsLevel = sqrt(floatArray.map { $0 * $0 }.reduce(0, +) / Float(floatArray.count))
        if rmsLevel < 0.01 {
            print("Audio too quiet (RMS: \(rmsLevel)), skipping transcription")
            return nil
        }
        
        do {
            let result = try await manager.transcribe(floatArray)
            let finalResult = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return finalResult.isEmpty ? nil : finalResult
        } catch {
            print("Parakeet transcription failed: \(error)")
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