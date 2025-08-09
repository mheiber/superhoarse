import Foundation

protocol SpeechRecognitionEngine {
    var isInitialized: Bool { get }
    var engineName: String { get }
    
    func initialize() async throws
    func transcribe(_ audioData: Data, completion: @escaping (String?) -> Void)
}

enum SpeechEngineType: String, CaseIterable {
    case whisper = "whisper"
    case parakeet = "parakeet"
    
    var displayName: String {
        switch self {
        case .whisper:
            return "Whisper (Default)"
        case .parakeet:
            return "Parakeet (Faster)"
        }
    }
}