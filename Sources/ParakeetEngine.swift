import Foundation
import FluidAudio

class ParakeetEngine: SpeechRecognitionEngine {
    private var asrManager: AsrManager?
    private let queue = DispatchQueue(label: "parakeet.recognition", qos: .userInitiated)
    
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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                let config = ASRConfig()
                self?.asrManager = AsrManager(config: config)
                print("Parakeet engine initialized successfully")
                continuation.resume()
            }
        }
    }
    
    func transcribe(_ audioData: Data, completion: @escaping (String?) -> Void) {
        Task {
            await performTranscription(audioData, completion: completion)
        }
    }
    
    private func performTranscription(_ audioData: Data, completion: @escaping (String?) -> Void) async {
        guard let manager = asrManager else {
            completion(nil)
            return
        }
        
        // Convert audio data to float array for Parakeet
        let floatArray = convertAudioDataToFloatArray(audioData)
        
        guard !floatArray.isEmpty else {
            completion(nil)
            return
        }
        
        // Skip very short recordings (less than 0.5 seconds at 16kHz)
        let minimumSamples = 8000  // 0.5 seconds at 16kHz
        if floatArray.count < minimumSamples {
            print("Audio too short (\(floatArray.count) samples), skipping transcription")
            completion(nil)
            return
        }
        
        // Check for mostly silent audio
        let rmsLevel = sqrt(floatArray.map { $0 * $0 }.reduce(0, +) / Float(floatArray.count))
        if rmsLevel < 0.01 {
            print("Audio too quiet (RMS: \(rmsLevel)), skipping transcription")
            completion(nil)
            return
        }
        
        do {
            let result = try await manager.transcribe(floatArray)
            
            DispatchQueue.main.async {
                let finalResult = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                completion(finalResult.isEmpty ? nil : finalResult)
            }
        } catch {
            print("Parakeet transcription failed: \(error)")
            DispatchQueue.main.async {
                completion(nil)
            }
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