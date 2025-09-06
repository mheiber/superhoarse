import Foundation
import CoreML
import FluidAudio
import os.log

/// Local implementation of AsrModels that uses bundled models instead of downloading
public class BundledAsrModels {
    private static let logger = Logger(subsystem: "com.superhoarse.lite", category: "BundledAsrModels")
    
    public struct ModelNames {
        public static let melspectrogram = "Melspectogram.mlmodelc"
        public static let encoder = "ParakeetEncoder_v2.mlmodelc"
        public static let decoder = "ParakeetDecoder.mlmodelc"
        public static let joint = "RNNTJoint.mlmodelc"
        public static let vocabulary = "parakeet_vocab.json"
    }
    
    /// Load bundled ASR models from the app bundle
    public static func loadBundledModels() throws -> AsrModels {
        logger.info("Loading bundled ASR models from app bundle")
        
        // Debug: List all resources in bundle
        if let resourcePath = Bundle.main.resourcePath {
            logger.info("Bundle resource path: \(resourcePath)")
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                logger.info("Bundle contents: \(contents)")
            }
        }
        
        // Get model URLs from bundle
        let melURL = Bundle.main.url(forResource: "Melspectogram", withExtension: "mlmodelc")
        let encoderURL = Bundle.main.url(forResource: "ParakeetEncoder_v2", withExtension: "mlmodelc")
        let decoderURL = Bundle.main.url(forResource: "ParakeetDecoder", withExtension: "mlmodelc")
        let jointURL = Bundle.main.url(forResource: "RNNTJoint", withExtension: "mlmodelc")
        let vocabURL = Bundle.main.url(forResource: "parakeet_vocab", withExtension: "json")
        
        logger.info("Model URLs found:")
        logger.info("  melURL: \(melURL?.path ?? "nil")")
        logger.info("  encoderURL: \(encoderURL?.path ?? "nil")")
        logger.info("  decoderURL: \(decoderURL?.path ?? "nil")")
        logger.info("  jointURL: \(jointURL?.path ?? "nil")") 
        logger.info("  vocabURL: \(vocabURL?.path ?? "nil")")
        
        guard let melURL = melURL,
              let encoderURL = encoderURL,
              let decoderURL = decoderURL,
              let jointURL = jointURL,
              let vocabURL = vocabURL else {
            throw BundledAsrModelsError.modelsNotFound("Required model files not found in app bundle")
        }
        
        logger.info("Found all model files in bundle")
        
        // Load vocabulary
        let vocabData = try Data(contentsOf: vocabURL)
        let vocabDict = try JSONDecoder().decode([String: String].self, from: vocabData)
        let vocabulary: [Int: String] = Dictionary(uniqueKeysWithValues: vocabDict.compactMap { (key, value) -> (Int, String)? in
            guard let intKey = Int(key) else { return nil }
            return (intKey, value)
        })
        
        // Create optimized configurations for each model
        let melConfig = optimizedConfiguration(for: .melSpectrogram)
        let encoderConfig = optimizedConfiguration(for: .encoder)
        let decoderConfig = optimizedConfiguration(for: .decoder)
        let jointConfig = optimizedConfiguration(for: .joint)
        
        // Load CoreML models
        logger.info("Loading melspectrogram model...")
        let melModel = try MLModel(contentsOf: melURL, configuration: melConfig)
        
        logger.info("Loading encoder model...")
        let encoderModel = try MLModel(contentsOf: encoderURL, configuration: encoderConfig)
        
        logger.info("Loading decoder model...")
        let decoderModel = try MLModel(contentsOf: decoderURL, configuration: decoderConfig)
        
        logger.info("Loading joint model...")
        let jointModel = try MLModel(contentsOf: jointURL, configuration: jointConfig)
        
        logger.info("All bundled models loaded successfully")
        
        return AsrModels(
            melspectrogram: melModel,
            encoder: encoderModel,
            decoder: decoderModel,
            joint: jointModel,
            configuration: melConfig, // Use one of the configs (they should be similar)
            vocabulary: vocabulary
        )
    }
    
    /// Create optimized configuration for different model types
    private static func optimizedConfiguration(for modelType: ANEOptimizer.ModelType) -> MLModelConfiguration {
        let config = MLModelConfiguration()
        config.computeUnits = ANEOptimizer.optimalComputeUnits(for: modelType)
        config.allowLowPrecisionAccumulationOnGPU = true
        return config
    }
    
    /// Check if all required models exist in the bundle
    public static func bundledModelsExist() -> Bool {
        let modelNames = [
            "Melspectogram.mlmodelc",
            "ParakeetEncoder_v2.mlmodelc", 
            "ParakeetDecoder.mlmodelc",
            "RNNTJoint.mlmodelc",
            "parakeet_vocab.json"
        ]
        
        for modelName in modelNames {
            let resourceName = String(modelName.dropLast(modelName.hasSuffix(".mlmodelc") ? 9 : 5))
            let ext = modelName.hasSuffix(".mlmodelc") ? "mlmodelc" : "json"
            
            if Bundle.main.url(forResource: resourceName, withExtension: ext) == nil {
                logger.warning("Missing bundled model: \(modelName)")
                return false
            }
        }
        
        return true
    }
}

public enum BundledAsrModelsError: Error, LocalizedError {
    case modelsNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelsNotFound(let message):
            return message
        }
    }
}