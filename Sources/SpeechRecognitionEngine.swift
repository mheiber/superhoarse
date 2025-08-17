import Foundation

protocol SpeechRecognitionEngine: Sendable {
    @MainActor var isInitialized: Bool { get }
    var engineName: String { get }
    
    @MainActor func initialize() async throws
    @MainActor func transcribe(_ audioData: Data) async -> String?
}

enum SpeechEngineType: String, CaseIterable {
    case parakeet = "parakeet"
    
    var displayName: String {
        switch self {
        case .parakeet:
            return "Parakeet"
        }
    }
}