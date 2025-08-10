import Foundation
import Combine

class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var transcriptionText = ""
    @Published var isInitialized = false
    
    private var hotKeyManager: HotKeyManager?
    private var audioRecorder: AudioRecorder?
    private var speechRecognizer: SpeechRecognizer?
    
    init() {
        setupHotKeyManager()
        setupAudioRecorder()
        setupSpeechRecognizer()
    }
    
    private func setupHotKeyManager() {
        hotKeyManager = HotKeyManager { [weak self] in
            self?.toggleRecording()
        }
    }
    
    private func setupAudioRecorder() {
        audioRecorder = AudioRecorder()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SpeechRecognizer()
        isInitialized = true
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard !isRecording else { return }
        
        audioRecorder?.startRecording()
        isRecording = true
        transcriptionText = ""
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stopRecording { [weak self] audioData in
            self?.processAudio(audioData)
        }
        isRecording = false
    }
    
    private func processAudio(_ audioData: Data?) {
        guard let audioData = audioData else { return }
        
        speechRecognizer?.transcribe(audioData) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleTranscriptionResult(result)
            }
        }
    }
    
    private func handleTranscriptionResult(_ text: String?) {
        guard let text = text, !text.isEmpty else { return }
        
        transcriptionText = text
        
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Insert text at cursor position
        insertTextAtCursor(text)
    }
    
    private func insertTextAtCursor(_ text: String) {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        event?.keyboardSetUnicodeString(string: text)
        event?.post(tap: .cghidEventTap)
    }
}