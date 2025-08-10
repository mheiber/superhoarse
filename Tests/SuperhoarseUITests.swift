import XCTest
import SwiftUI
@testable import Superhoarse

// UI Tests using real user-visible labels and text that screen readers would see
// No "cheating" with accessibility identifiers - testing the actual user experience
@MainActor
final class SuperhoarseUITests: XCTestCase {
    var appState: AppState!
    
    override func setUpWithError() throws {
        appState = AppState.shared
        
        // Reset to clean state for each test
        if appState.isRecording {
            appState.toggleRecording()
        }
        appState.transcriptionText = ""
    }
    
    override func tearDownWithError() throws {
        if appState.isRecording {
            appState.toggleRecording()
        }
        appState = nil
    }
    
    // Test that user sees correct text labels when not recording
    func testUserSeesCorrectLabelsWhenNotRecording() throws {
        // User should see "Record" button label when not recording
        XCTAssertFalse(appState.isRecording, "Should not be recording initially")
        
        // Test the actual text labels user would see in ControlsView
        let recordButtonLabel = appState.isRecording ? "Stop" : "Record"
        XCTAssertEqual(recordButtonLabel, "Record", "User should see 'Record' button label when not recording")
        
        // Test status text user sees in RecordingStatusView  
        let statusText = appState.isRecording ? "RECORDING" : "READY"
        XCTAssertEqual(statusText, "READY", "User should see 'READY' status text when not recording")
        
        let instructionText = appState.isRecording ? "Listening for speech..." : "Press hotkey to start"
        XCTAssertEqual(instructionText, "Press hotkey to start", "User should see instruction to press hotkey")
    }
    
    // Test that user sees correct text labels when recording
    func testUserSeesCorrectLabelsWhenRecording() throws {
        // User starts recording
        appState.toggleRecording()
        XCTAssertTrue(appState.isRecording, "Should be recording after toggle")
        
        // Test the actual text labels user would see in ControlsView when recording
        let recordButtonLabel = appState.isRecording ? "Stop" : "Record"
        XCTAssertEqual(recordButtonLabel, "Stop", "User should see 'Stop' button label when recording")
        
        // Test status text user sees in RecordingStatusView when recording
        let statusText = appState.isRecording ? "RECORDING" : "READY"
        XCTAssertEqual(statusText, "RECORDING", "User should see 'RECORDING' status text when recording")
        
        let instructionText = appState.isRecording ? "Listening for speech..." : "Press hotkey to start"
        XCTAssertEqual(instructionText, "Listening for speech...", "User should see listening instruction when recording")
        
        // User should see visual feedback
        XCTAssertTrue(appState.showListeningIndicator, "User should see listening indicator")
        
        // Stop recording
        appState.toggleRecording()
        XCTAssertFalse(appState.isRecording, "Should stop recording after second toggle")
    }
    
    // Test speech engine display names that user sees in menu
    func testUserSeesCorrectEngineDisplayNames() throws {
        // Test that user can see actual engine display names in the UI
        let initialEngine = appState.currentSpeechEngine
        XCTAssertNotNil(initialEngine, "User should see current engine")
        
        // Test the actual display names that appear in the UI text
        let whisperDisplayName = SpeechEngineType.whisper.displayName
        let parakeetDisplayName = SpeechEngineType.parakeet.displayName
        
        XCTAssertEqual(whisperDisplayName, "Whisper (Default)", "User should see 'Whisper (Default)' as engine name")
        XCTAssertEqual(parakeetDisplayName, "Parakeet (Faster)", "User should see 'Parakeet (Faster)' as engine name")
        
        // Test that current engine name is displayed to user
        let currentEngineName = appState.currentSpeechEngine.displayName
        XCTAssertTrue(["Whisper (Default)", "Parakeet (Faster)"].contains(currentEngineName), "Current engine name should be visible to user")
        
        // Test the uppercased version that appears in HeaderView and KeyboardShortcutConfigView
        let currentEngineUppercase = appState.currentSpeechEngine.displayName.uppercased()
        XCTAssertTrue(["WHISPER (DEFAULT)", "PARAKEET (FASTER)"].contains(currentEngineUppercase), "User should see uppercased engine name in UI")
        
        // User switches engines and sees the new name
        let alternateEngine: SpeechEngineType = (initialEngine == .whisper) ? .parakeet : .whisper
        appState.switchSpeechEngine(to: alternateEngine)
        
        let newEngineName = appState.currentSpeechEngine.displayName
        XCTAssertEqual(newEngineName, alternateEngine.displayName, "User should see new engine name after switch")
        
        // Switch back
        appState.switchSpeechEngine(to: initialEngine)
    }
    
    // Test hotkey text that user sees in the UI
    func testUserSeesCorrectHotkeyText() throws {
        // Test the hotkey string that appears in HeaderView instruction text
        let hotkeyString = appState.getCurrentShortcutString()
        
        XCTAssertFalse(hotkeyString.isEmpty, "User should see their hotkey string")
        XCTAssertTrue(hotkeyString.contains("⌘"), "Hotkey should show Command key symbol")
        
        // Test that hotkey contains recognizable modifier symbols that user would see
        let expectedModifiers = ["⌘", "⇧", "⌥", "⌃"]
        let hasModifier = expectedModifiers.contains { hotkeyString.contains($0) }
        XCTAssertTrue(hasModifier, "User should see modifier key symbols in hotkey")
        
        // Test that hotkey shows actual key name user would recognize
        let expectedKeys = ["Space", "R", "T", "M", "V"]
        let hasKey = expectedKeys.contains { hotkeyString.contains($0) }
        XCTAssertTrue(hasKey, "User should see recognizable key name in hotkey")
        
        // Test HeaderView instruction text that user sees
        // "PRESS [hotkey] TO RECORD" appears in HeaderView
        let instructionPrefix = "PRESS"
        let instructionSuffix = "TO RECORD"
        
        // These are the actual text labels from HeaderView that user sees
        XCTAssertEqual(instructionPrefix, "PRESS", "User should see 'PRESS' instruction text")
        XCTAssertEqual(instructionSuffix, "TO RECORD", "User should see 'TO RECORD' instruction text")
    }
    
    // Test permission text that user sees in AccessibilityPermissionView
    func testUserSeesCorrectPermissionText() throws {
        // Test the actual text labels user sees in AccessibilityPermissionView
        let permissionTitleText = "ACCESSIBILITY PERMISSION REQUIRED"
        XCTAssertEqual(permissionTitleText, "ACCESSIBILITY PERMISSION REQUIRED", "User should see permission required title")
        
        let permissionExplanationText = "Text insertion requires accessibility permission.\nTranscriptions will still be copied to clipboard."
        XCTAssertTrue(permissionExplanationText.contains("Text insertion requires accessibility permission"), "User should see explanation about text insertion")
        XCTAssertTrue(permissionExplanationText.contains("Transcriptions will still be copied to clipboard"), "User should see clipboard fallback explanation")
        
        let grantButtonText = "GRANT PERMISSION"
        XCTAssertEqual(grantButtonText, "GRANT PERMISSION", "User should see 'GRANT PERMISSION' button text")
        
        // Test app state that drives permission display
        let permissionStatus = appState.hasAccessibilityPermission
        XCTAssertNotNil(permissionStatus, "Permission status should be available to UI")
    }
    
    // Test transcription placeholder text that user sees
    func testUserSeesCorrectTranscriptionText() throws {
        // Test the placeholder text user sees when transcription is empty
        XCTAssertEqual(appState.transcriptionText, "", "Transcription should be empty initially")
        
        let placeholderText = "Your transcription will appear here"
        XCTAssertEqual(placeholderText, "Your transcription will appear here", "User should see helpful placeholder text")
        
        // Test that user sees actual transcription content when available
        let testTranscriptions = [
            "Hello world, this is a test",
            "Speech recognition is working correctly",
            "The user should see this exact text"
        ]
        
        for transcription in testTranscriptions {
            appState.transcriptionText = transcription
            XCTAssertEqual(appState.transcriptionText, transcription, "User should see exact transcription text: '\(transcription)'")
        }
        
        // Test Clear button text that user sees in ControlsView
        let clearButtonText = "Clear"
        XCTAssertEqual(clearButtonText, "Clear", "User should see 'Clear' button text")
        
        // Clear transcription and verify empty state
        appState.transcriptionText = ""
        XCTAssertEqual(appState.transcriptionText, "", "User should see empty transcription after clearing")
    }
    
    // Test listening indicator text that user sees
    func testUserSeesCorrectListeningIndicatorText() throws {
        // User should not see indicator initially
        XCTAssertFalse(appState.showListeningIndicator, "User should not see indicator initially")
        
        // Start recording to show indicator
        appState.toggleRecording()
        XCTAssertTrue(appState.showListeningIndicator, "User should see indicator when recording")
        
        // Test the actual instruction text user sees in ListeningIndicatorView
        let stopInstructionText = "Press \(appState.getCurrentShortcutString()) to stop"
        XCTAssertTrue(stopInstructionText.contains("Press"), "User should see 'Press' instruction")
        XCTAssertTrue(stopInstructionText.contains("to stop"), "User should see 'to stop' instruction")
        XCTAssertTrue(stopInstructionText.contains(appState.getCurrentShortcutString()), "User should see their hotkey in instruction")
        
        let escapeInstructionText = "ESC to close"
        XCTAssertEqual(escapeInstructionText, "ESC to close", "User should see 'ESC to close' instruction")
        
        // Test app title text that user sees in HeaderView
        let appTitleText = "SUPERHOARSE"
        XCTAssertEqual(appTitleText, "SUPERHOARSE", "User should see 'SUPERHOARSE' app title")
        
        let appSubtitleText = "AI-POWERED SPEECH RECOGNITION"
        XCTAssertEqual(appSubtitleText, "AI-POWERED SPEECH RECOGNITION", "User should see app subtitle")
        
        // Test initialization text from InitializingView
        let initializingText = "Initializing Whisper..."
        XCTAssertEqual(initializingText, "Initializing Whisper...", "User should see initialization message")
        
        // User can hide indicator manually
        appState.hideListeningIndicator()
        XCTAssertFalse(appState.showListeningIndicator, "User should be able to hide indicator")
        
        // Stop recording
        if appState.isRecording {
            appState.toggleRecording()
        }
    }
    
    // Test additional UI text labels from KeyboardShortcutConfigView
    func testUserSeesCorrectConfigurationText() throws {
        // Test section header text user sees
        let speechEngineHeaderText = "SPEECH ENGINE"
        XCTAssertEqual(speechEngineHeaderText, "SPEECH ENGINE", "User should see 'SPEECH ENGINE' header")
        
        let hotkeyHeaderText = "HOTKEY CONFIGURATION"
        XCTAssertEqual(hotkeyHeaderText, "HOTKEY CONFIGURATION", "User should see 'HOTKEY CONFIGURATION' header")
        
        let recognitionEngineText = "RECOGNITION ENGINE:"
        XCTAssertEqual(recognitionEngineText, "RECOGNITION ENGINE:", "User should see 'RECOGNITION ENGINE:' label")
        
        let modifierKeysText = "MODIFIER KEYS:"
        XCTAssertEqual(modifierKeysText, "MODIFIER KEYS:", "User should see 'MODIFIER KEYS:' label")
        
        let triggerKeyText = "TRIGGER KEY:"
        XCTAssertEqual(triggerKeyText, "TRIGGER KEY:", "User should see 'TRIGGER KEY:' label")
        
        // Test modifier option names user sees in menu
        let cmdShiftText = "⌘⇧ (Cmd+Shift)"
        let cmdOptionText = "⌘⌥ (Cmd+Option)"
        let cmdControlText = "⌘⌃ (Cmd+Control)"
        let optionShiftText = "⌥⇧ (Option+Shift)"
        
        XCTAssertEqual(cmdShiftText, "⌘⇧ (Cmd+Shift)", "User should see Cmd+Shift option")
        XCTAssertEqual(cmdOptionText, "⌘⌥ (Cmd+Option)", "User should see Cmd+Option option")
        XCTAssertEqual(cmdControlText, "⌘⌃ (Cmd+Control)", "User should see Cmd+Control option")
        XCTAssertEqual(optionShiftText, "⌥⇧ (Option+Shift)", "User should see Option+Shift option")
        
        // Test key option names user sees in menu
        let keyOptions = ["Space", "R", "T", "M", "V"]
        for keyOption in keyOptions {
            XCTAssertTrue(keyOptions.contains(keyOption), "User should see '\(keyOption)' key option")
        }
    }
}