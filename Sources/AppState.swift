import Foundation
import Combine
import ApplicationServices
import AppKit
import SwiftUI
import os.log

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isRecording = false
    @Published var transcriptionText = ""
    @Published var isInitialized = false
    @Published var hasAccessibilityPermission = false
    @Published var showListeningIndicator = false
    
    private var hotKeyManager: HotKeyManager?
    var audioRecorder: AudioRecorder?
    private var speechRecognizer: SpeechRecognizer?
    
    private let logger = Logger(subsystem: "com.superwhisper.lite", category: "AppState")
    
    private init() {
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
        logger.info("Toggle recording called. Currently recording: \(self.isRecording)")
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard !isRecording else { return }
        
        logger.info("Starting recording...")
        audioRecorder?.startRecording()
        isRecording = true
        showListeningIndicator = true
        transcriptionText = ""
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        logger.info("Stopping recording...")
        audioRecorder?.stopRecording { [weak self] audioData in
            self?.processAudio(audioData)
        }
        isRecording = false
        showListeningIndicator = false
    }
    
    private func processAudio(_ audioData: Data?) {
        guard let audioData = audioData else { 
            logger.error("No audio data received")
            return 
        }
        
        logger.info("Processing audio data (\(audioData.count) bytes)...")
        speechRecognizer?.transcribe(audioData) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleTranscriptionResult(result)
            }
        }
    }
    
    private func handleTranscriptionResult(_ text: String?) {
        guard let text = text, !text.isEmpty else { 
            logger.error("No transcription result received")
            return 
        }
        
        logger.info("Transcription received: '\(text)'")
        transcriptionText = text
        
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: NSPasteboard.PasteboardType.string)
        logger.info("Text copied to clipboard")
        
        // Insert text at cursor position only if we have permission
        if hasAccessibilityPermission {
            logger.info("Inserting text at cursor...")
            let sanitizedText = sanitizeTextForInsertion(text)
            insertTextAtCursor(sanitizedText)
        } else {
            logger.error("Accessibility permission required for text insertion")
        }
    }
    
    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }
        
        if !trusted {
            logger.error("Accessibility permission not granted. Text insertion will be disabled.")
            logger.info("Please grant accessibility permission in System Preferences > Security & Privacy > Privacy > Accessibility")
        }
    }
    
    func requestAccessibilityPermissions() {
        // First, try to perform an actual accessibility action to trigger the system prompt
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        event?.post(tap: .cghidEventTap)
        
        // Then check permissions with prompt
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }
        
        // If still not trusted, open System Preferences directly
        if !trusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
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
    
    func getCurrentShortcutString() -> String {
        let modifierValue = UserDefaults.standard.integer(forKey: "hotKeyModifier")
        let keyCodeValue = UserDefaults.standard.integer(forKey: "hotKeyCode")
        
        let modifierString: String
        switch modifierValue {
        case 0: modifierString = "⌘⇧"
        case 1: modifierString = "⌘⌥"
        case 2: modifierString = "⌘⌃"
        case 3: modifierString = "⌥⇧"
        default: modifierString = "⌘⇧"
        }
        
        let keyString: String
        switch keyCodeValue > 0 ? keyCodeValue : 49 {
        case 49: keyString = "Space"
        case 15: keyString = "R"
        case 17: keyString = "T"
        case 46: keyString = "M"
        case 9: keyString = "V"
        default: keyString = "Key(\(keyCodeValue))"
        }
        
        return "\(modifierString)\(keyString)"
    }
    
    func hideListeningIndicator() {
        showListeningIndicator = false
    }
    
    private func insertTextAtCursor(_ text: String) {
        guard hasAccessibilityPermission else {
            logger.error("Cannot insert text: Accessibility permission not granted")
            return
        }
        
        logger.info("About to insert text: '\(text)'")
        
        // Ensure we can post events to the current focused application
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            logger.error("Failed to create CGEvent")
            return
        }
        
        let unicodeString = Array(text.utf16)
        event.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString)
        
        // Post to the active application (not just our app)
        event.post(tap: .cghidEventTap)
        logger.info("Text insertion event posted")
        
        // Also try posting a key-up event to complete the sequence
        if let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
            upEvent.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString)
            upEvent.post(tap: .cghidEventTap)
            logger.info("Text insertion up-event posted")
        }
    }
}