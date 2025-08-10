import Foundation
import CryptoKit
import whisper

@MainActor
class WhisperEngine: @preconcurrency SpeechRecognitionEngine {
    private var whisperContext: OpaquePointer?
    
    var isInitialized: Bool {
        return whisperContext != nil
    }
    
    let engineName = "Whisper"
    
    init() {
        Task {
            try await initialize()
        }
    }
    
    func initialize() async throws {
        let modelPath = getModelPath()
        
        if !FileManager.default.fileExists(atPath: modelPath) {
            print("Downloading Whisper base model...")
            let success = await downloadBaseModel(to: modelPath)
            if !success {
                print("Failed to download Whisper model")
                return
            }
        }
        
        loadModel(at: modelPath)
    }
    
    deinit {
        if let context = whisperContext {
            whisper_free(context)
        }
    }
    
    private func getModelPath() -> String {
        let modelsDir: URL
        
        #if os(Linux)
        // On Linux, use ~/.local/share/Superhoarse/Models
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        modelsDir = homeDir
            .appendingPathComponent(".local/share")
            .appendingPathComponent("Superhoarse/Models")
        #else
        // On macOS, use the application support directory
        modelsDir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask).first!
            .appendingPathComponent("Superhoarse/Models")
        #endif
        
        try? FileManager.default.createDirectory(at: modelsDir,
                                               withIntermediateDirectories: true)
        
        return modelsDir.appendingPathComponent("ggml-base.bin").path
    }
    
    private func downloadBaseModel(to path: String) async -> Bool {
        let urlString = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
        let expectedHash = "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe"
        
        guard let url = URL(string: urlString) else {
            print("Invalid model download URL")
            return false
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.httpMaximumConnectionsPerHost = 1
        
        let session = URLSession(configuration: config)
        
        do {
            let (tempURL, response) = try await session.download(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Model download failed with HTTP status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return false
            }
            
            let data = try Data(contentsOf: tempURL)
            let calculatedHash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            
            guard calculatedHash == expectedHash else {
                print("Hash verification failed. Expected: \(expectedHash), Got: \(calculatedHash)")
                return false
            }
            
            try FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: path))
            print("Model downloaded and verified successfully")
            return true
        } catch {
            print("Failed to download or verify model: \(error)")
            return false
        }
    }
    
    private func loadModel(at path: String) {
        let params = whisper_context_default_params()
        whisperContext = whisper_init_from_file_with_params(path, params)
        
        if whisperContext == nil {
            print("Failed to load Whisper model")
        }
    }
    
    func transcribe(_ audioData: Data) async -> String? {
        guard let context = whisperContext else { return nil }
        
        let floatArray = convertAudioDataToFloatArray(audioData)
        
        guard !floatArray.isEmpty else { return nil }
        
        let minimumSamples = 8000
        if floatArray.count < minimumSamples {
            return nil
        }
        
        let rmsLevel = sqrt(floatArray.map { $0 * $0 }.reduce(0, +) / Float(floatArray.count))
        if rmsLevel < 0.01 {
            return nil
        }
        
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        let langId = whisper_lang_id("en")
        params.language = langId >= 0 ? "en".withCString { $0 } : nil
        params.translate = false
        params.print_realtime = false
        params.print_progress = false
        params.suppress_blank = true
        params.suppress_non_speech_tokens = false
        params.temperature = 0.0
        params.max_tokens = 0
        params.audio_ctx = 0
        params.initial_prompt = "".withCString { $0 }
        
        let result = whisper_full(context, params, floatArray, Int32(floatArray.count))
        
        guard result == 0 else { return nil }
        
        let segmentCount = whisper_full_n_segments(context)
        var transcription = ""
        
        for i in 0..<segmentCount {
            if let segmentText = whisper_full_get_segment_text(context, i) {
                let segment = String(cString: segmentText)
                let cleanedSegment = filterTranscriptionArtifacts(segment)
                if !cleanedSegment.isEmpty {
                    transcription += cleanedSegment
                }
            }
        }
        
        let finalResult = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        return finalResult.isEmpty ? nil : finalResult
    }
    
    private func filterTranscriptionArtifacts(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let bracketsPattern = "\\[[^\\]]*\\]"
        var cleaned = trimmed.replacingOccurrences(of: bracketsPattern,
                                                   with: "",
                                                   options: .regularExpression)
        let singleWordParenPattern = "\\([a-zA-Z]+\\)"
        cleaned = cleaned.replacingOccurrences(of: singleWordParenPattern,
                                               with: "",
                                               options: .regularExpression)
        cleaned = String(cleaned.unicodeScalars.filter { scalar in
            let categories: [Unicode.GeneralCategory] = [
                .uppercaseLetter, .lowercaseLetter, .titlecaseLetter,
                .modifierLetter, .otherLetter,
                .nonspacingMark, .enclosingMark,
                .letterNumber, .otherNumber,
                .connectorPunctuation, .dashPunctuation, .openPunctuation,
                .closePunctuation, .otherPunctuation,
                .mathSymbol, .currencySymbol, .modifierSymbol,
                .lineSeparator, .paragraphSeparator, .spaceSeparator
            ]
            return categories.contains(scalar.properties.generalCategory) ||
                   scalar.isASCII ||
                   scalar.value == 0x2019 ||
                   scalar.value == 0x201C ||
                   scalar.value == 0x201D
        })
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count < 3 && !cleaned.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return ""
        }
        if cleaned.count > 3 {
            let uniqueChars = Set(cleaned.lowercased())
            if uniqueChars.count <= 2 && cleaned.count > 10 {
                return ""
            }
        }
        return cleaned
    }
    
    private func convertAudioDataToFloatArray(_ data: Data) -> [Float] {
        let int16Array = data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Int16.self))
        }
        return int16Array.map { Float($0) / Float(Int16.max) }
    }
}