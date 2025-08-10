import Foundation
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
        let modelsDir = FileManager.default.urls(for: .applicationSupportDirectory, 
                                               in: .userDomainMask).first!
            .appendingPathComponent("SuperWhisperLite/Models")
        
        try? FileManager.default.createDirectory(at: modelsDir, 
                                               withIntermediateDirectories: true)
        
        return modelsDir.appendingPathComponent("ggml-base.bin").path
    }
    
    private func downloadBaseModel(to path: String, completion: @escaping (Bool) -> Void) {
        // Download the base Whisper model
        let urlString = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            guard let tempURL = tempURL, error == nil else {
                completion(false)
                return
            }
            
            do {
                try FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: path))
                completion(true)
            } catch {
                print("Failed to move downloaded model: \(error)")
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