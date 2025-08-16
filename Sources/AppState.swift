import Foundation
import Combine
import ApplicationServices
import AppKit
import SwiftUI
import os.log

struct TimeoutError: Error {
    let message = "Operation timed out"
}

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isRecording = false
    @Published var transcriptionText = ""
    @Published var isInitialized = false
    @Published var hasAccessibilityPermission = false
    @Published var showListeningIndicator = false
    @Published var currentAudioLevel: Float = 0.0
    @Published var currentSpeechEngine: SpeechEngineType = .parakeet
    
    private var hotKeyManager: HotKeyManager?
    private var permissionCheckTimer: Timer?
    var audioRecorder: AudioRecorder?
    private var parakeetEngine: SpeechRecognitionEngine?
    private var currentEngine: SpeechRecognitionEngine? {
        return parakeetEngine
    }
    private var audioLevelCancellable: AnyCancellable?
    
    private let logger = Logger(subsystem: "com.superhoarse.lite", category: "AppState")
    
    deinit {
        permissionCheckTimer?.invalidate()
    }
    
    private init() {
        updateAccessibilityPermission()
        setupHotKeyManager()
        setupAudioRecorder()
        Task {
            await setupSpeechRecognizer()
        }
    }
    
    private func setupHotKeyManager() {
        hotKeyManager = HotKeyManager { [weak self] in
            self?.toggleRecording()
        }
    }
    
    private func setupAudioRecorder() {
        audioRecorder = AudioRecorder()
        
        // Subscribe to audio level changes
        audioLevelCancellable = audioRecorder?.$currentAudioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentAudioLevel, on: self)
    }
    
    private func setupSpeechRecognizer() async {
        parakeetEngine = ParakeetEngine()
        currentSpeechEngine = .parakeet
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
        
        // Ensure audio recorder is in a good state before starting
        if audioRecorder == nil {
            logger.warning("Audio recorder was nil, recreating...")
            setupAudioRecorder()
        }
        
        audioRecorder?.startRecording()
        isRecording = true
        showListeningIndicator = true
        transcriptionText = ""
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        logger.info("Stopping recording...")
        audioRecorder?.stopRecording { [weak self] audioData in
            Task {
                await self?.processAudio(audioData)
            }
        }
        isRecording = false
        showListeningIndicator = false
        
        // Add timeout to ensure we don't get stuck in a recording state
        DispatchQueue.main.asyncAfter(deadline: .now() + 35) { [weak self] in
            guard let self = self else { return }
            if self.isRecording {
                self.logger.error("Recording state stuck, forcing reset")
                self.isRecording = false
                self.showListeningIndicator = false
            }
        }
    }
    
    private func processAudio(_ audioData: Data?) async {
        guard let audioData = audioData else { 
            logger.error("No audio data received")
            return 
        }
        
        logger.info("Processing audio data (\(audioData.count) bytes) using \(self.currentSpeechEngine.displayName)...")
        
        // Add timeout and resource management for transcription
        let transcriptionTask = Task {
            var result = await currentEngine?.transcribe(audioData)
            
            
            return result
        }
        
        // Add timeout to prevent hung transcription from blocking subsequent recordings
        do {
            let result = try await withTimeout(seconds: 30) {
                await transcriptionTask.value
            }
            handleTranscriptionResult(result)
        } catch {
            logger.error("Transcription timed out or failed: \(error)")
            handleTranscriptionResult(nil)
        }
    }
    
    // Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
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
        
        // Fix: Re-check permission just-in-time before attempting to insert text.
        updateAccessibilityPermission()
        
        // Insert text at cursor position only if we have permission
        if hasAccessibilityPermission {
            logger.info("Inserting text at cursor...")
            let sanitizedText = sanitizeTextForInsertion(text)
            insertTextAtCursor(sanitizedText)
        } else {
            logger.error("Accessibility permission denied. Text will not be inserted.")
        }
    }
    
    // Renamed and modified to be a synchronous update.
    func updateAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        // Log bundle information for debugging
        if let bundleId = Bundle.main.bundleIdentifier {
            logger.info("Checking permissions for bundle ID: \(bundleId)")
        } else {
            logger.warning("No bundle ID found - running as unbundled executable")
        }
        
        logger.info("Process name: \(ProcessInfo.processInfo.processName)")
        logger.info("Accessibility permission status: \(trusted)")
        
        // Update the published property on the main thread.
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }
        
        if !trusted {
            logger.error("Accessibility permission not granted. Text insertion will be disabled.")
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
        
        // If still not trusted, open System Preferences directly and start monitoring
        if !trusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            // Start polling for permission changes
            startPermissionMonitoring()
        }
    }
    
    func startPermissionMonitoring() {
        // Cancel any existing timer
        permissionCheckTimer?.invalidate()
        
        // Check permissions every 2 seconds
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
            let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
            
            DispatchQueue.main.async {
                let wasPermissionGranted = !self.hasAccessibilityPermission && trusted
                self.hasAccessibilityPermission = trusted
                
                // Stop monitoring once permission is granted
                if trusted {
                    self.stopPermissionMonitoring()
                    if wasPermissionGranted {
                        self.logger.info("Accessibility permission granted - monitoring stopped")
                    }
                }
            }
        }
        
        // Stop monitoring after 5 minutes to prevent indefinite polling
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
            self.stopPermissionMonitoring()
        }
    }
    
    func stopPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
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
    
    func switchSpeechEngine(to engineType: SpeechEngineType) {
        currentSpeechEngine = engineType
        UserDefaults.standard.set(engineType.rawValue, forKey: "speechEngine")
        logger.info("Switched speech engine to \(engineType.displayName)")
    }
    
    private func insertTextAtCursor(_ text: String) {
        guard hasAccessibilityPermission else {
            logger.error("Cannot insert text: Accessibility permission not granted")
            return
        }
        
        logger.info("About to insert text: '\(text)'")
        
        // Create keyboard event for text insertion
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            logger.error("Failed to create CGEvent")
            return
        }
        
        let unicodeString = Array(text.utf16)
        event.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString)
        
        // Post to the currently focused application (whatever is active right now)
        event.post(tap: .cghidEventTap)
        logger.info("Text insertion event posted to focused application")
        
        // Post key-up event
        if let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
            upEvent.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString)
            upEvent.post(tap: .cghidEventTap)
            logger.info("Text insertion up-event posted")
        }
    }
}