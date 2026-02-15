import Foundation
import CoreML
import FluidAudio
import os.log

/// Local implementation of AsrModels that uses bundled models instead of downloading
public class BundledAsrModels {
    private static let logger = Logger(subsystem: "com.superhoarse.lite", category: "BundledAsrModels")

    public struct ModelNames {
        public static let preprocessor = "Preprocessor.mlmodelc"
        public static let encoder = "Encoder.mlmodelc"
        public static let decoder = "Decoder.mlmodelc"
        public static let joint = "JointDecision.mlmodelc"
        public static let vocabulary = "parakeet_vocab.json"
    }

    /// Load bundled ASR models from the app bundle
    public static func loadBundledModels() throws -> AsrModels {
        logger.info("Loading bundled ASR models from app bundle")

        let bundle = bundleForResources()

        // Debug: List all resources in bundle
        if let resourcePath = bundle.resourcePath {
            logger.info("Bundle resource path: \(resourcePath)")
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                logger.info("Bundle contents: \(contents)")
            }
        }

        // Get model URLs from bundle
        let preprocessorURL = bundle.url(forResource: "Preprocessor", withExtension: "mlmodelc")
        let encoderURL = bundle.url(forResource: "Encoder", withExtension: "mlmodelc")
        let decoderURL = bundle.url(forResource: "Decoder", withExtension: "mlmodelc")
        let jointURL = bundle.url(forResource: "JointDecision", withExtension: "mlmodelc")
        let vocabURL = bundle.url(forResource: "parakeet_vocab", withExtension: "json")

        logger.info("Model URLs found:")
        logger.info("  preprocessorURL: \(preprocessorURL?.path ?? "nil")")
        logger.info("  encoderURL: \(encoderURL?.path ?? "nil")")
        logger.info("  decoderURL: \(decoderURL?.path ?? "nil")")
        logger.info("  jointURL: \(jointURL?.path ?? "nil")")
        logger.info("  vocabURL: \(vocabURL?.path ?? "nil")")

        guard let preprocessorURL = preprocessorURL,
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
        let preprocessorConfig = optimizedConfiguration(for: .cpuOnly)
        let encoderConfig = optimizedConfiguration(for: .cpuAndNeuralEngine)
        let decoderConfig = optimizedConfiguration(for: .cpuAndNeuralEngine)
        let jointConfig = optimizedConfiguration(for: .cpuAndNeuralEngine)

        // Load CoreML models
        logger.info("Loading preprocessor model...")
        let preprocessorModel = try MLModel(contentsOf: preprocessorURL, configuration: preprocessorConfig)

        logger.info("Loading encoder model...")
        let encoderModel = try MLModel(contentsOf: encoderURL, configuration: encoderConfig)

        logger.info("Loading decoder model...")
        let decoderModel = try MLModel(contentsOf: decoderURL, configuration: decoderConfig)

        logger.info("Loading joint model...")
        let jointModel = try MLModel(contentsOf: jointURL, configuration: jointConfig)

        logger.info("All bundled models loaded successfully")

        return AsrModels(
            encoder: encoderModel,
            preprocessor: preprocessorModel,
            decoder: decoderModel,
            joint: jointModel,
            configuration: encoderConfig,
            vocabulary: vocabulary,
            version: .v3
        )
    }

    /// Get the appropriate bundle for resources, handling both SwiftPM and Xcode builds
    private static func bundleForResources() -> Bundle {
        // Try Bundle.module first (SwiftPM)
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        // Fallback to Bundle.main (Xcode)
        return Bundle.main
        #endif
    }

    /// Create optimized configuration for different compute unit targets
    private static func optimizedConfiguration(for computeUnits: MLComputeUnits) -> MLModelConfiguration {
        let config = MLModelConfiguration()
        config.computeUnits = computeUnits
        config.allowLowPrecisionAccumulationOnGPU = true
        return config
    }

    /// Check if all required models exist in the bundle
    public static func bundledModelsExist() -> Bool {
        let bundle = bundleForResources()
        let modelNames = [
            "Preprocessor.mlmodelc",
            "Encoder.mlmodelc",
            "Decoder.mlmodelc",
            "JointDecision.mlmodelc",
            "parakeet_vocab.json"
        ]

        for modelName in modelNames {
            let resourceName = String(modelName.dropLast(modelName.hasSuffix(".mlmodelc") ? 9 : 5))
            let ext = modelName.hasSuffix(".mlmodelc") ? "mlmodelc" : "json"

            if bundle.url(forResource: resourceName, withExtension: ext) == nil {
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
