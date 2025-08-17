import Foundation
import FluidAudio
import os.log

enum ParakeetEngineError: Error {
    case initializationFailed(String)
    case transcriptionFailed(String)
}

@MainActor
class ParakeetEngine: SpeechRecognitionEngine {
    private var asrManager: AsrManager?
    private let logger = Logger(subsystem: "com.superhoarse.lite", category: "ParakeetEngine")
    
    var isInitialized: Bool {
        return asrManager != nil
    }
    
    let engineName = "Parakeet"
    
    init() {
        // Initialization is now handled explicitly by the caller
    }
    
    func initialize() async throws {
        logger.info("Starting ParakeetEngine initialization...")
        do {
            // Optimized configuration for short audio transcription
            let tdtConfig = TdtConfig(
                durations: [0, 1, 2, 3, 4, 5],  // Extended duration range for flexibility
                includeTokenDuration: true,
                maxSymbolsPerStep: 5             // Prevent decoder from getting stuck on blanks
            )
            
            let config = ASRConfig(
                maxSymbolsPerFrame: 5,           // Increased from default 3 for aggressive decoding
                enableDebug: true,               // Enable for troubleshooting short audio issues
                realtimeMode: true,              // Better for short utterances
                chunkSizeMs: 1000,               // Smaller chunks (1s) for short audio
                tdtConfig: tdtConfig
            )
            logger.info("Created optimized ASRConfig for short audio transcription")
            let manager = AsrManager(config: config)
            logger.info("Created AsrManager")
            
            // Initialize the AsrManager using the recommended approach
            let models = try await AsrModels.downloadAndLoad()
            logger.info("Downloaded and loaded ASR models")
            try await manager.initialize(models: models)
            logger.info("AsrManager.initialize(models:) completed")
            
            self.asrManager = manager
            
            // Verify the manager was created and is functional
            guard self.asrManager != nil else {
                throw ParakeetEngineError.initializationFailed("AsrManager creation failed")
            }
            
            logger.info("ParakeetEngine initialization completed successfully")
        } catch {
            logger.error("Parakeet engine initialization failed: \(error)")
            self.asrManager = nil
            throw ParakeetEngineError.initializationFailed("Failed to initialize: \(error)")
        }
    }
    
    func transcribe(_ audioData: Data) async -> String? {
        logger.info("Starting transcription with \(audioData.count) bytes of audio data")
        
        guard let manager = asrManager else {
            logger.error("Transcription failed: Parakeet engine not initialized")
            return nil
        }
        
        // Convert audio data to float array for Parakeet
        let floatArray = convertAudioDataToFloatArray(audioData)
        logger.info("Converted to float array with \(floatArray.count) samples")
        
        guard !floatArray.isEmpty else {
            logger.error("Transcription failed: Empty audio data after conversion to float array")
            return nil
        }
        
        // FluidAudio requires minimum 1 second of audio (16000 samples at 16kHz)
        let minimumSamples = 16000  // 1 second at 16kHz (FluidAudio requirement)
        if floatArray.count < minimumSamples {
            let durationSeconds = Double(floatArray.count) / 16000.0
            logger.info("Transcription skipped: Audio too short (\(String(format: "%.2f", durationSeconds)) seconds, minimum 1.0 seconds required by FluidAudio)")
            return nil
        }
        
        // Check for mostly silent audio
//        let rmsLevel = sqrt(floatArray.map { $0 * $0 }.reduce(0, +) / Float(floatArray.count))
//        if rmsLevel < 0.01 {
        // 
//            logger.info("Transcription skipped: Audio mostly silent (RMS level: \(String(format: "%.4f", rmsLevel)), minimum 0.01 required)")
//            return nil
//        }
        
        do {
            let result = try await manager.transcribe(floatArray)
            let finalResult = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if finalResult.isEmpty {
                logger.info("Transcription result empty: Engine returned whitespace-only or empty text")
                return nil
            }
            return finalResult
        } catch {
            logger.error("Transcription failed: Parakeet engine error - \(error.localizedDescription)")
            // If transcription fails due to engine issues, mark as uninitialized so it can be recreated
            if error.localizedDescription.contains("notInitialized") {
                logger.warning("Marking Parakeet engine as uninitialized due to engine error")
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
