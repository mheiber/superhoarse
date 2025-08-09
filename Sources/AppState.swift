import Foundation
import Combine
import ApplicationServices

class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var transcriptionText = ""
    @Published var isInitialized = false
    @Published var hasAccessibilityPermission = false
    
    private var hotKeyManager: HotKeyManager?
    private var audioRecorder: AudioRecorder?
    private var speechRecognizer: SpeechRecognizer?
    
    init() {
        checkAccessibilityPermissions()
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
        
        // Insert text at cursor position only if we have permission
        if hasAccessibilityPermission {
            let sanitizedText = sanitizeTextForInsertion(text)
            insertTextAtCursor(sanitizedText)
        } else {
            print("Accessibility permission required for text insertion")
        }
    }
    
    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }
        
        if !trusted {
            print("Accessibility permission not granted. Text insertion will be disabled.")
            print("Please grant accessibility permission in System Preferences > Security & Privacy > Privacy > Accessibility")
        }
    }
    
    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }
    }
    
    private func sanitizeTextForInsertion(_ text: String) -> String {
        // Remove potentially dangerous characters and control sequences
        var sanitized = text
        
        // Remove control characters except common whitespace
        sanitized = sanitized.filter { char in
            return !char.isASCII || char.isLetter || char.isNumber || char.isPunctuation || char.isWhitespace
        }
        
        // Remove common keyboard shortcuts patterns
        let dangerousPatterns = [
            "⌘", "⌥", "⌃", "⇧",  // Command, Option, Control, Shift symbols
            "\u{F700}", "\u{F701}", "\u{F702}", "\u{F703}",  // Arrow keys
            "\u{F704}", "\u{F705}", "\u{F706}", "\u{F707}",  // Function keys
            "\u{F708}", "\u{F709}", "\u{F70A}", "\u{F70B}",
            "\u{F70C}", "\u{F70D}", "\u{F70E}", "\u{F70F}"
        ]
        
        for pattern in dangerousPatterns {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "")
        }
        
        // Limit length to prevent abuse
        if sanitized.count > 1000 {
            sanitized = String(sanitized.prefix(1000))
        }
        
        return sanitized
    }
    
    private func insertTextAtCursor(_ text: String) {
        guard hasAccessibilityPermission else {
            print("Cannot insert text: Accessibility permission not granted")
            return
        }
        
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        event?.keyboardSetUnicodeString(string: text)
        event?.post(tap: .cghidEventTap)
    }
}