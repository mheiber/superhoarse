import Foundation
import CryptoKit
import whisper

class SpeechRecognizer {
    private var whisperContext: OpaquePointer?
    private let queue = DispatchQueue(label: "speech.recognition", qos: .userInitiated)
    
    init() {
        setupWhisper()
    }
    
    deinit {
        if let context = whisperContext {
            whisper_free(context)
        }
    }
    
    private func setupWhisper() {
        queue.async { [weak self] in
            self?.initializeWhisperModel()
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
        // On Linux, use ~/.local/share/SuperWhisperLite/Models
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        modelsDir = homeDir
            .appendingPathComponent(".local/share")
            .appendingPathComponent("SuperWhisperLite/Models")
        #else
        // On macOS, use the application support directory
        modelsDir = FileManager.default.urls(for: .applicationSupportDirectory, 
                                           in: .userDomainMask).first!
            .appendingPathComponent("SuperWhisperLite/Models")
        #endif
        
        try? FileManager.default.createDirectory(at: modelsDir, 
                                               withIntermediateDirectories: true)
        
        return modelsDir.appendingPathComponent("ggml-base.bin").path
    }
    
    private func downloadBaseModel(to path: String, completion: @escaping (Bool) -> Void) {
        // Download the base Whisper model with integrity verification
        let urlString = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
        // Known SHA-256 hash for ggml-base.bin model (should be updated when model changes)
        let expectedHash = "60ed5bc3dd14eea856493d334349b405782e8c6c5bb8f41058bfbaafa54a4b6b"
        
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
                // Verify file integrity with SHA-256
                let downloadedData = try Data(contentsOf: tempURL)
                let computedHash = SHA256.hash(data: downloadedData)
                let computedHashString = computedHash.compactMap { String(format: "%02x", $0) }.joined()
                
                guard computedHashString.lowercased() == expectedHash.lowercased() else {
                    print("Model integrity check failed. Expected: \(expectedHash), Got: \(computedHashString)")
                    completion(false)
                    return
                }
                
                // Move verified file to final location
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
        whisperContext = whisper_init_from_file(path)
        
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
        
        // Set up Whisper parameters
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.language = whisper_lang_id("en")  // English by default
        params.translate = false
        params.print_realtime = false
        params.print_progress = false
        
        // Run transcription
        let result = whisper_full(context, params, floatArray, Int32(floatArray.count))
        
        guard result == 0 else {
            completion(nil)
            return
        }
        
        // Extract text
        let segmentCount = whisper_full_n_segments(context)
        var transcription = ""
        
        for i in 0..<segmentCount {
            if let segmentText = whisper_full_get_segment_text(context, i) {
                transcription += String(cString: segmentText)
            }
        }
        
        DispatchQueue.main.async {
            completion(transcription.trimmingCharacters(in: .whitespacesAndNewlines))
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