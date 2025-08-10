import Foundation

@preconcurrency protocol SpeechRecognitionEngine: Sendable {
    var isInitialized: Bool { get }
    var engineName: String { get }
    
    func initialize() async throws
    func transcribe(_ audioData: Data) async -> String?
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