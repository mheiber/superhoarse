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
            // Use default configuration with debug enabled for troubleshooting
            let config = ASRConfig(enableDebug: false)
            logger.info("Created optimized ASRConfig for short audio transcription")
            let manager = AsrManager(config: config)
            logger.info("Created AsrManager")
            
            // Load bundled models only (no network access)
            logger.info("Loading bundled ASR models (no network required)")
            let models = try BundledAsrModels.loadBundledModels()
            logger.info("Loaded bundled ASR models")
            
            try await manager.initialize(models: models)
            logger.info("AsrManager.initialize(models:) completed")
            
            self.asrManager = manager
            
            // Verify the manager was created and is functional
            guard self.asrManager != nil else {
                throw ParakeetEngineError.initializationFailed("AsrManager creation failed")
            }
            
            // Reset decoder state to ensure clean initialization
            try await manager.resetDecoderState(for: .microphone)
            logger.info("Reset decoder state for clean initialization")
            
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
        
        // Reset decoder state before each transcription to prevent state corruption
        do {
            try await manager.resetDecoderState(for: .microphone)
            logger.debug("Reset decoder state before transcription")
        } catch {
            logger.warning("Failed to reset decoder state: \(error), continuing with existing state")
        }
        
        guard !floatArray.isEmpty else {
            logger.error("Transcription failed: Empty audio data after conversion to float array")
            return nil
        }
        
        // FluidAudio requires minimum 1 second of audio (16000 samples at 16kHz)
        let minimumSamples = 16000  // 1 second at 16kHz (FluidAudio requirement)
        if floatArray.count < minimumSamples {
            let durationSeconds = Double(floatArray.count) / 16000.0
            logger.info("Audio shorter than minimum (\(String(format: "%.2f", durationSeconds))s), but attempting transcription with padding")
            // Don't return nil - let FluidAudio handle the padding and try to transcribe anyway
        }
        
        // Check for mostly silent audio
//        let rmsLevel = sqrt(floatArray.map { $0 * $0 }.reduce(0, +) / Float(floatArray.count))
//        if rmsLevel < 0.01 {
        // 
//            logger.info("Transcription skipped: Audio mostly silent (RMS level: \(String(format: "%.4f", rmsLevel)), minimum 0.01 required)")
//            return nil
//        }
        
        do {
            logger.debug("Starting transcription call to FluidAudio")
            let result = try await manager.transcribe(floatArray)
            logger.debug("FluidAudio transcription completed - confidence: \(result.confidence), duration: \(result.duration)")
            
            let finalResult = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if finalResult.isEmpty {
                let durationSeconds = Double(floatArray.count) / 16000.0
                logger.info("⚠️ Empty transcription for \(String(format: "%.1f", durationSeconds))s audio (confidence: \(result.confidence), processing time: \(result.processingTime))")
                return nil
            }
            
            logger.info("✅ Successful transcription: '\(finalResult)' (confidence: \(result.confidence))")
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
