import Foundation
import Combine
import ApplicationServices
import AppKit
import SwiftUI
import os.log
import CoreGraphics

struct TimeoutError: Error {
    let message = "Operation timed out"
}

struct HotkeyConfiguration {
    static let modifierOptions = [
        (name: "⌥ (Option)", symbol: "⌥", value: 0),
        (name: "⌘⇧ (Cmd+Shift)", symbol: "⌘⇧", value: 1),
        (name: "⌘⌥ (Cmd+Option)", symbol: "⌘⌥", value: 2),
        (name: "⌘⌃ (Cmd+Control)", symbol: "⌘⌃", value: 3),
        (name: "⌥⇧ (Option+Shift)", symbol: "⌥⇧", value: 4)
    ]
    
    static let keyOptions = [
        (name: "Space", code: 49),
        (name: "R", code: 15),
        (name: "T", code: 17),
        (name: "M", code: 46),
        (name: "V", code: 9)
    ]
    
    static func getModifierSymbol(for value: Int) -> String {
        return modifierOptions.first { $0.value == value }?.symbol ?? "⌘⇧"
    }
    
    static func getKeyName(for code: Int) -> String {
        return keyOptions.first { $0.code == code }?.name ?? "Key(\(code))"
    }
}

class GlobalEscapeKeyMonitor {
    private var eventTap: CFMachPort?
    private let logger = Logger(subsystem: "com.superhoarse.lite", category: "EscapeKeyMonitor")
    private var onEscapePressed: (() -> Void)?
    
    func startMonitoring(onEscape: @escaping () -> Void) {
        guard eventTap == nil else {
            logger.warning("Escape key monitoring already active")
            return
        }
        
        onEscapePressed = onEscape
        
        // Create event tap to intercept key down events
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) in
                let monitor = Unmanaged<GlobalEscapeKeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            logger.error("Failed to create escape key event tap - accessibility permissions may be required")
            return
        }
        
        // Create run loop source and add to current run loop
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        logger.info("Global escape key monitoring started")
    }
    
    func stopMonitoring() {
        guard let eventTap = eventTap else {
            return
        }
        
        // Disable and release the event tap
        CGEvent.tapEnable(tap: eventTap, enable: false)
        CFMachPortInvalidate(eventTap)
        self.eventTap = nil
        onEscapePressed = nil
        
        logger.info("Global escape key monitoring stopped")
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Check if this is an escape key press
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == 53 { // Escape key code
                logger.info("Escape key intercepted - canceling recording")
                onEscapePressed?()
                // Return nil to consume the event and prevent it from reaching other applications
                return nil
            }
        }
        
        // For all other events, pass them through unchanged
        return Unmanaged.passUnretained(event)
    }
    
    deinit {
        stopMonitoring()
    }
}

// =============================================================================
// AppState: Smart Hold-to-Record (PTT) + Tap-to-Toggle Recording
// =============================================================================
//
// RECORDING MODE LOGIC (READ THIS BEFORE MODIFYING):
//
// This app supports TWO ways to record, using the same or different hotkeys:
//
//   1. HOLD-TO-RECORD (Push-to-Talk / PTT):
//      User holds the hotkey while speaking. Recording stops when they release.
//
//   2. TAP-TO-TOGGLE:
//      User taps the hotkey once to start recording, taps again to stop.
//
// HOW IT WORKS — TWO SCENARIOS:
//
// SCENARIO A: Toggle key and PTT key are the SAME (default)
//   - On key-down: start recording immediately.
//   - On key-up: check how long the key was held.
//     - If held >= 200ms (holdThreshold): this was a HOLD → stop recording.
//     - If held < 200ms: this was a TAP → keep recording, enter toggle mode.
//   - In toggle mode: next key-down stops recording. ESC cancels.
//   - The 200ms threshold comes from whisper.cpp's talk.cpp reference implementation.
//     A normal intentional tap is 100-150ms; holding to say even "yes" takes 400ms+.
//
// SCENARIO B: Toggle key and PTT key are DIFFERENT
//   - No timing ambiguity. Each key has exactly one behavior.
//   - Toggle key down: if recording → stop; if not → start (toggle mode).
//   - Toggle key up: ignored.
//   - PTT key down: start recording.
//   - PTT key up: stop recording (regardless of hold duration).
//
// ESCAPE KEY BEHAVIOR:
//   - In toggle mode (after a tap), ESC cancels recording. Both hands are free.
//   - During hold (key is physically down), ESC is NOT monitored because the
//     user's hand is occupied holding the hotkey and can't easily reach ESC.
//   - The escape monitor starts only when we enter toggle mode.
//
// UI FEEDBACK (see ListeningIndicatorView in ContentView.swift):
//   - While holding (before we know if it's hold or toggle):
//     Shows "Release {hotkey} to stop" — no ESC instruction.
//   - After tap (toggle mode):
//     Shows "ESC to cancel" + "{hotkey} to stop" — both hands are free.
//
// =============================================================================

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isRecording = false
    @Published var transcriptionText = ""
    @Published var isInitialized = false
    @Published var hasAccessibilityPermission = false
    @Published var showListeningIndicator = false
    @Published var showPasteNotification = false
    @Published var showAccessibilityNotification = false
    @Published var shouldOpenSettings = false
    @Published var currentAudioLevel: Float = 0.0
    @Published var currentSpeechEngine: SpeechEngineType = .parakeet
    @Published var copyToClipboard: Bool = UserDefaults.standard.object(forKey: "copyToClipboard") as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(copyToClipboard, forKey: "copyToClipboard")
        }
    }

    // -- Hold/Toggle state --
    // When true, the user tapped (< 200ms) and we're in toggle mode.
    // When false, the user is either holding or not recording.
    // The listening indicator uses this to decide which instructions to show.
    @Published var recordingIsToggleMode = false

    // Tracks whether the hotkey is physically held down right now.
    // Used to prevent re-triggering on key-repeat events from the OS.
    private var isHolding = false

    // Timestamp of the most recent key-down event, used to measure hold duration.
    private var keyDownTime: Date? = nil

    // Threshold in seconds to distinguish a tap from a hold.
    // < 200ms = tap (toggle mode), >= 200ms = hold (PTT mode).
    // This value comes from whisper.cpp's talk.cpp reference implementation.
    // See CLAUDE.md for rationale.
    private let holdThreshold: TimeInterval = 0.2

    private var hotKeyManager: HotKeyManager?
    private var permissionCheckTimer: Timer?
    var audioRecorder: AudioRecorder?
    private var parakeetEngine: SpeechRecognitionEngine?
    private var currentEngine: SpeechRecognitionEngine? {
        return parakeetEngine
    }
    private var audioLevelCancellable: AnyCancellable?
    private var escapeKeyMonitor: GlobalEscapeKeyMonitor?

    private let logger = Logger(subsystem: "com.superhoarse.lite", category: "AppState")
    
    deinit {
        permissionCheckTimer?.invalidate()
    }
    
    private init() {
        logger.info("AppState initializing...")
        updateAccessibilityPermission()
        setupHotKeyManager()
        setupAudioRecorder()
        
        // Start continuous permission monitoring to detect grant/revoke changes
        startPermissionMonitoring()
        
        Task {
            logger.info("Starting speech recognizer setup task...")
            await setupSpeechRecognizer()
        }
    }
    
    private func setupHotKeyManager() {
        hotKeyManager = HotKeyManager(
            onKeyDown: { [weak self] identity in self?.handleKeyDown(identity) },
            onKeyUp: { [weak self] identity in self?.handleKeyUp(identity) }
        )
    }
    
    private func setupAudioRecorder() {
        audioRecorder = AudioRecorder()
        
        // Subscribe to audio level changes
        audioLevelCancellable = audioRecorder?.$currentAudioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentAudioLevel, on: self)
    }
    
    private func setupSpeechRecognizer() async {
        logger.info("Setting up speech recognizer...")
        let engine = ParakeetEngine()
        do {
            logger.info("Calling engine.initialize()...")
            try await engine.initialize()
            logger.info("Engine initialization successful, setting up app state...")
            parakeetEngine = engine
            currentSpeechEngine = .parakeet
            isInitialized = true
            logger.info("Speech recognizer setup completed successfully")
        } catch {
            logger.error("Failed to initialize speech engine: \(error)")
            isInitialized = false
        }
    }
    
    // =========================================================================
    // Key Event Handlers
    // =========================================================================
    // These are called by HotKeyManager when the user presses/releases a hotkey.
    // The HotKeyIdentity tells us which key was involved:
    //   .shared — toggle and PTT are the same key, use timing to disambiguate
    //   .toggle — dedicated toggle key, always toggles
    //   .ptt    — dedicated PTT key, always hold-to-record

    func handleKeyDown(_ identity: HotKeyIdentity) {
        logger.info("Key down: identity=\(String(describing: identity)), isRecording=\(self.isRecording), isHolding=\(self.isHolding), toggleMode=\(self.recordingIsToggleMode)")

        switch identity {
        case .shared:
            // Same key for both modes. Behavior depends on current state.
            if isRecording && recordingIsToggleMode {
                // We're in toggle mode and user pressed again → stop recording.
                stopRecording()
            } else if !isRecording {
                // Not recording → start. We don't know yet if this is a tap or hold.
                // We'll find out in handleKeyUp based on timing.
                keyDownTime = Date()
                isHolding = true
                recordingIsToggleMode = false
                startRecording(startEscapeMonitor: false) // Don't start ESC monitor during hold
            }
            // If isRecording && !recordingIsToggleMode && isHolding:
            // This is a key-repeat event from the OS. Ignore it.

        case .toggle:
            // Dedicated toggle key — always toggles, no timing logic needed.
            if isRecording {
                stopRecording()
            } else {
                recordingIsToggleMode = true
                isHolding = false
                startRecording(startEscapeMonitor: true)
            }

        case .ptt:
            // Dedicated PTT key — always hold-to-record. Key-up stops it.
            if !isRecording {
                isHolding = true
                recordingIsToggleMode = false
                startRecording(startEscapeMonitor: false)
            }
            // If already recording (key repeat), ignore.
        }
    }

    func handleKeyUp(_ identity: HotKeyIdentity) {
        logger.info("Key up: identity=\(String(describing: identity)), isRecording=\(self.isRecording), isHolding=\(self.isHolding)")

        switch identity {
        case .shared:
            guard isRecording, isHolding else { return }
            isHolding = false

            // Measure how long the key was held to decide: was this a tap or a hold?
            let elapsed = keyDownTime.map { Date().timeIntervalSince($0) } ?? 1.0

            if elapsed >= holdThreshold {
                // Held for >= 200ms → this was a HOLD. Stop recording now.
                logger.info("Hold detected (\(String(format: "%.0f", elapsed * 1000))ms) — stopping recording")
                stopRecording()
            } else {
                // Released quickly (< 200ms) → this was a TAP. Enter toggle mode.
                // Recording continues. User will press again to stop, or ESC to cancel.
                logger.info("Tap detected (\(String(format: "%.0f", elapsed * 1000))ms) — entering toggle mode")
                recordingIsToggleMode = true
                // Now start escape key monitoring since both hands are free.
                startEscapeKeyMonitoring()
            }

        case .toggle:
            // Dedicated toggle key — key-up is irrelevant for toggle behavior.
            break

        case .ptt:
            // Dedicated PTT key — release always stops recording.
            if isRecording {
                isHolding = false
                stopRecording()
            }
        }
    }

    // Keep toggleRecording() as a convenience for the UI record/stop button.
    func toggleRecording() {
        logger.info("Toggle recording called. Currently recording: \(self.isRecording)")
        if isRecording {
            stopRecording()
        } else {
            recordingIsToggleMode = true
            startRecording(startEscapeMonitor: true)
        }
    }

    private func startRecording(startEscapeMonitor: Bool = true) {
        guard !isRecording else { return }

        logger.info("Starting recording...")

        // Ensure audio recorder is in a good state before starting
        if audioRecorder == nil {
            logger.warning("Audio recorder was nil, recreating...")
            setupAudioRecorder()
        }

        // Only start escape key monitoring if requested.
        // During hold-to-record, we DON'T monitor ESC because the user's hand
        // is occupied holding the hotkey. ESC monitoring starts later if the
        // key-up reveals this was actually a tap (toggle mode).
        if startEscapeMonitor {
            startEscapeKeyMonitoring()
        }

        audioRecorder?.startRecording()
        isRecording = true
        showListeningIndicator = true
        transcriptionText = ""
    }

    /// Starts the global escape key monitor. Separated out so it can be called
    /// either at recording start (toggle mode) or deferred until after key-up
    /// reveals a tap (shared key mode).
    private func startEscapeKeyMonitoring() {
        if escapeKeyMonitor == nil {
            escapeKeyMonitor = GlobalEscapeKeyMonitor()
        }
        escapeKeyMonitor?.startMonitoring { [weak self] in
            Task { @MainActor in
                self?.cancelRecording()
            }
        }
    }

    private func stopRecording() {
        guard isRecording else { return }

        logger.info("Stopping recording...")

        // Stop escape key monitoring
        escapeKeyMonitor?.stopMonitoring()

        // Reset hold/toggle state
        isHolding = false
        recordingIsToggleMode = false
        keyDownTime = nil

        audioRecorder?.stopRecording { [weak self] audioData in
            Task {
                await self?.processAudio(audioData)
            }
        }
        isRecording = false
        showListeningIndicator = false

    }
    
    private func processAudio(_ audioData: Data?) async {
        guard let audioData = audioData else { 
            logger.error("Transcription failed: No audio data received from recording")
            return 
        }
        
        logger.info("Processing audio data (\(audioData.count) bytes) using \(self.currentSpeechEngine.displayName)...")
        
        // Check if engine is properly initialized
        guard let engine = currentEngine else {
            logger.error("Transcription failed: No current engine available")
            return
        }
        
        if let parakeetEngine = engine as? ParakeetEngine {
            logger.info("Using ParakeetEngine, isInitialized: \(parakeetEngine.isInitialized)")
        }
        
        // Add timeout and resource management for transcription
        let transcriptionTask = Task {
            let result = await currentEngine?.transcribe(audioData)
            return result
        }
        
        // Add timeout to prevent hung transcription from blocking subsequent recordings
        do {
            let result = try await withTimeout(seconds: 30) {
                await transcriptionTask.value
            }
            handleTranscriptionResult(result)
        } catch {
            if error is TimeoutError {
                logger.error("Transcription failed: Operation timed out after 30 seconds")
            } else {
                logger.error("Transcription failed: \(error.localizedDescription)")
            }
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
            if text == nil {
                logger.error("Transcription failed: Engine returned nil result")
            } else {
                logger.error("Transcription failed: Engine returned empty string")
            }
            return 
        }
        
        logger.info("Transcription received: '\(text)'")
        transcriptionText = text

        // Copy to clipboard only if enabled
        if copyToClipboard {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: NSPasteboard.PasteboardType.string)
            logger.info("Text copied to clipboard")
        }

        // Fix: Re-check permission just-in-time before attempting to insert text.
        updateAccessibilityPermission()

        // Insert text at cursor position only if we have permission
        if hasAccessibilityPermission {
            logger.info("Inserting text at cursor...")
            let sanitizedText = sanitizeTextForInsertion(text)
            insertTextAtCursor(sanitizedText)
        } else if copyToClipboard {
            logger.info("Accessibility permission denied. Showing paste notification instead.")
            showPasteNotification = true
        } else {
            logger.info("Accessibility permission denied and clipboard disabled. Showing accessibility notification.")
            showAccessibilityNotification = true
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
                let wasPermissionRevoked = self.hasAccessibilityPermission && !trusted
                self.hasAccessibilityPermission = trusted
                
                if wasPermissionGranted {
                    self.logger.info("Accessibility permission granted")
                } else if wasPermissionRevoked {
                    self.logger.info("Accessibility permission revoked - will continue monitoring")
                }
            }
        }
        
        // Continue monitoring indefinitely to detect permission changes
        // No automatic timeout - monitoring continues throughout app lifecycle
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

        let modifierString = HotkeyConfiguration.getModifierSymbol(for: modifierValue)
        let keyString = HotkeyConfiguration.getKeyName(for: keyCodeValue > 0 ? keyCodeValue : 49)

        return "\(modifierString)\(keyString)"
    }

    /// Returns the display string for the PTT hotkey (e.g., "⌘⇧Space").
    /// When the PTT key is not explicitly set (UserDefaults returns 0),
    /// falls back to the toggle key — which is the default "same key" config.
    func getCurrentPTTShortcutString() -> String {
        let modifierValue = UserDefaults.standard.integer(forKey: "hotKeyModifier")
        let pttKeyCodeValue = UserDefaults.standard.integer(forKey: "hotKeyCodePTT")
        let toggleKeyCodeValue = UserDefaults.standard.integer(forKey: "hotKeyCode")

        let modifierString = HotkeyConfiguration.getModifierSymbol(for: modifierValue)
        // Fall back to toggle key if PTT key is not explicitly set
        let effectivePTTCode = pttKeyCodeValue > 0 ? pttKeyCodeValue : (toggleKeyCodeValue > 0 ? toggleKeyCodeValue : 49)
        let keyString = HotkeyConfiguration.getKeyName(for: effectivePTTCode)

        return "\(modifierString)\(keyString)"
    }
    
    func hideListeningIndicator() {
        showListeningIndicator = false
    }
    
    func hidePasteNotification() {
        showPasteNotification = false
    }

    func hideAccessibilityNotification() {
        showAccessibilityNotification = false
    }
    
    func cancelRecording() {
        if isRecording {
            logger.info("Recording cancelled by user")

            // Stop escape key monitoring
            escapeKeyMonitor?.stopMonitoring()

            // Reset hold/toggle state
            isHolding = false
            recordingIsToggleMode = false
            keyDownTime = nil

            audioRecorder?.stopRecording { _ in
                // Discard the audio data when cancelled
            }
            isRecording = false
        }
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
        
        // Verify there's a focused application that can receive text
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            logger.error("No frontmost application found")
            return
        }
        logger.info("Inserting text into application: \(frontmostApp.localizedName ?? "Unknown")")
        
        // Create keyboard event for text insertion
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(0), keyDown: true) else {
            logger.error("Failed to create CGEvent")
            return
        }
        
        let unicodeString = Array(text.utf16)
        event.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString)
        
        // Set event flags to ensure it's treated as a regular key event
        event.flags = []
        
        // Post to the currently focused application
        event.post(tap: .cghidEventTap)
        logger.info("Text insertion event posted to focused application")
        
        // Add small delay before posting key-up event (some apps need this)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(0), keyDown: false) else {
                self?.logger.error("Failed to create key-up CGEvent")
                return
            }
            
            upEvent.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString)
            upEvent.flags = []
            upEvent.post(tap: .cghidEventTap)
            self?.logger.info("Text insertion up-event posted")
        }
    }
}
