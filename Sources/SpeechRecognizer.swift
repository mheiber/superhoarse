import Foundation
import CryptoKit
import whisper

class WhisperEngine: SpeechRecognitionEngine {
    private var whisperContext: OpaquePointer?
    private let queue = DispatchQueue(label: "speech.recognition", qos: .userInitiated)
    
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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                self?.initializeWhisperModel()
                continuation.resume()
            }
        }
    }
    
    deinit {
        if let context = whisperContext {
            whisper_free(context)
        }
    }
    
    
    private func initializeWhisperModel() {
        // Use the built-in base model from whisper.cpp
        // This will download automatically if needed
        let modelPath = getModelPath()
        
        guard FileManager.default.fileExists(atPath: modelPath) else {
            print("Downloading Whisper base model...")
            downloadBaseModel(to: modelPath) { [weak self] success in
                if success {
                    self?.loadModel(at: modelPath)
                } else {
                    print("Failed to download Whisper model")
                }
            }
            return
        }
        
        loadModel(at: modelPath)
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
    
    private func downloadBaseModel(to path: String, completion: @escaping (Bool) -> Void) {
        // Download the base Whisper model with integrity verification
        let urlString = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
        // Known SHA-256 hash for ggml-base.bin model from HuggingFace
        let expectedHash = "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe"
        
        guard let url = URL(string: urlString) else {
            print("Invalid model download URL")
            completion(false)
            return
        }
        
        // Create secure URLSession configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.httpMaximumConnectionsPerHost = 1
        
        let session = URLSession(configuration: config)
        
        session.downloadTask(with: url) { tempURL, response, error in
            defer { session.invalidateAndCancel() }
            
            guard let tempURL = tempURL, error == nil else {
                print("Model download failed: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            
            // Verify HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    print("Model download failed with HTTP status: \(httpResponse.statusCode)")
                    completion(false)
                    return
                }
            }
            
            do {
                // Verify SHA-256 hash before moving file
                let data = try Data(contentsOf: tempURL)
                let calculatedHash = SHA256.hash(data: data)
                let hashString = calculatedHash.compactMap { String(format: "%02x", $0) }.joined()
                
                guard hashString == expectedHash else {
                    print("Hash verification failed. Expected: \(expectedHash), Got: \(hashString)")
                    completion(false)
                    return
                }
                
                // Move downloaded file to final location
                try FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: path))
                print("Model downloaded and verified successfully")
                completion(true)
            } catch {
                print("Failed to verify or move downloaded model: \(error)")
                completion(false)
            }
        }.resume()
    }
    
    private func loadModel(at path: String) {
        let params = whisper_context_default_params()
        whisperContext = whisper_init_from_file_with_params(path, params)
        
        if whisperContext != nil {
            print("Whisper model loaded successfully")
        } else {
            print("Failed to load Whisper model")
        }
    }
    
    func transcribe(_ audioData: Data, completion: @escaping (String?) -> Void) {
        queue.async { [weak self] in
            self?.performTranscription(audioData, completion: completion)
        }
    }
    
    private func performTranscription(_ audioData: Data, completion: @escaping (String?) -> Void) {
        guard let context = whisperContext else {
            completion(nil)
            return
        }
        
        // Convert audio data to float array for Whisper
        let floatArray = convertAudioDataToFloatArray(audioData)
        
        guard !floatArray.isEmpty else {
            completion(nil)
            return
        }
        
        // Skip very short recordings (less than 0.5 seconds at 16kHz)
        // These often produce artifacts like [BLANK_AUDIO]
        let minimumSamples = 8000  // 0.5 seconds at 16kHz
        if floatArray.count < minimumSamples {
            print("Audio too short (\(floatArray.count) samples), skipping transcription")
            completion(nil)
            return
        }
        
        // Check for mostly silent audio (RMS < threshold)
        let rmsLevel = sqrt(floatArray.map { $0 * $0 }.reduce(0, +) / Float(floatArray.count))
        if rmsLevel < 0.01 {  // Very quiet threshold
            print("Audio too quiet (RMS: \(rmsLevel)), skipping transcription")
            completion(nil)
            return
        }
        
        // Set up Whisper parameters with artifact reduction
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        let langId = whisper_lang_id("en")
        params.language = langId >= 0 ? "en".withCString { $0 } : nil
        params.translate = false
        params.print_realtime = false
        params.print_progress = false
        
        // Research-based parameter tuning to reduce artifacts
        params.suppress_blank = true        // Suppress blank outputs
        params.suppress_non_speech_tokens = false  // Keep false to avoid hallucinations!
        params.temperature = 0.0           // Use greedy decoding (more deterministic) 
        params.max_tokens = 0              // No token limit
        params.audio_ctx = 0               // Use full audio context
        params.initial_prompt = "".withCString { $0 }  // No initial prompt to avoid bias
        
        // Run transcription
        let result = whisper_full(context, params, floatArray, Int32(floatArray.count))
        
        guard result == 0 else {
            completion(nil)
            return
        }
        
        // Extract text with artifact filtering
        let segmentCount = whisper_full_n_segments(context)
        var transcription = ""
        
        for i in 0..<segmentCount {
            if let segmentText = whisper_full_get_segment_text(context, i) {
                let segment = String(cString: segmentText)
                
                // Skip common Whisper artifacts
                let cleanedSegment = filterTranscriptionArtifacts(segment)
                if !cleanedSegment.isEmpty {
                    transcription += cleanedSegment
                }
            }
        }
        
        let finalResult = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        DispatchQueue.main.async {
            // Return nil if result is empty or only contains artifacts
            completion(finalResult.isEmpty ? nil : finalResult)
        }
    }
    
    private func filterTranscriptionArtifacts(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove anything between square brackets [...] - covers [BLANK_AUDIO], [Silence], [Split], etc.
        let bracketsPattern = "\\[[^\\]]*\\]"
        var cleaned = trimmed.replacingOccurrences(of: bracketsPattern, 
                                                   with: "", 
                                                   options: .regularExpression)
        
        // Remove single word parentheticals like (music), (silence), (noise), (laughter)
        let singleWordParenPattern = "\\([a-zA-Z]+\\)"
        cleaned = cleaned.replacingOccurrences(of: singleWordParenPattern,
                                               with: "",
                                               options: .regularExpression)
        
        // Remove non-linguistic Unicode characters (symbols, emojis, music notes, etc.)
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
            
            // Keep basic linguistic characters and common punctuation
            return categories.contains(scalar.properties.generalCategory) ||
                   scalar.isASCII ||  // Keep all ASCII
                   scalar.value == 0x2019 ||  // Right single quotation mark '
                   scalar.value == 0x201C ||  // Left double quotation mark "
                   scalar.value == 0x201D     // Right double quotation mark "
        })
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Filter out very short unclear segments (likely artifacts)
        if cleaned.count < 3 && !cleaned.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return ""
        }
        
        // Filter repetitive characters (common artifact pattern)
        if cleaned.count > 3 {
            let uniqueChars = Set(cleaned.lowercased())
            if uniqueChars.count <= 2 && cleaned.count > 10 {
                return ""  // Likely "aaaaa" or "hmhmhm" type artifacts
            }
        }
        
        return cleaned
    }
    
    private func convertAudioDataToFloatArray(_ data: Data) -> [Float] {
        // Convert 16-bit PCM to float array
        let int16Array = data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Int16.self))
        }
        
        return int16Array.map { Float($0) / Float(Int16.max) }
    }
}