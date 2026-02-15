import XCTest
import SwiftUI
@testable import Superhoarse

// These tests simulate complete user workflows by testing the integration 
// between UI components and business logic, ensuring the user experience works correctly
@MainActor
final class SuperhoarseUserWorkflowTests: XCTestCase {
    var appState: AppState!
    
    override func setUpWithError() throws {
        appState = AppState.shared
        
        // Reset to clean state
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
    
    // Test complete user workflow: User opens app and sees expected interface state
    func testUserOpensAppAndSeesExpectedInterface() {
        // User opens app and expects to see clean initial state
        XCTAssertFalse(appState.isRecording, "User should see recording is not active")
        XCTAssertEqual(appState.transcriptionText, "", "User should see empty transcription area")
        XCTAssertNotNil(appState.currentSpeechEngine, "User should see a selected speech engine")
        XCTAssertFalse(appState.showListeningIndicator, "User should not see listening indicator")
        
        // User should be able to see their hotkey configuration
        let hotkeyString = appState.getCurrentShortcutString()
        XCTAssertFalse(hotkeyString.isEmpty, "User should see their hotkey configuration")
        // Test that hotkey contains any valid modifier (default is ⌥, not ⌘)
        let validModifiers = ["⌘", "⇧", "⌥", "⌃"]
        let hasValidModifier = validModifiers.contains { hotkeyString.contains($0) }
        XCTAssertTrue(hasValidModifier, "Hotkey should show valid modifier key for user")
    }
    
    // Test user workflow: User clicks record button and sees immediate feedback
    func testUserClicksRecordButtonAndSeesImmediateFeedback() {
        // User clicks the record button (simulating UI button action)
        appState.toggleRecording()
        
        // User immediately sees visual feedback
        XCTAssertTrue(appState.isRecording, "User should see recording state changed")
        XCTAssertTrue(appState.showListeningIndicator, "User should see listening indicator appear")
        XCTAssertEqual(appState.transcriptionText, "", "Previous transcription should be cleared for user")
        
        // User clicks stop (simulating second button click)
        appState.toggleRecording()
        
        // User sees recording stopped
        XCTAssertFalse(appState.isRecording, "User should see recording stopped")
        // Note: listening indicator might still be visible briefly, which is expected UX
    }
    
    // Test user workflow: User switches speech engines and sees results
    func testUserSwitchesSpeechEnginesAndSeesResults() {
        let originalEngine = appState.currentSpeechEngine
        // Only parakeet engine is available now
        let alternateEngine: SpeechEngineType = .parakeet
        
        // User selects different speech engine from menu
        appState.switchSpeechEngine(to: alternateEngine)
        
        // User sees engine changed in interface
        XCTAssertEqual(appState.currentSpeechEngine, alternateEngine, "User should see engine changed")
        
        // User can see engine display name for UI
        let engineDisplayName = alternateEngine.displayName
        XCTAssertFalse(engineDisplayName.isEmpty, "User should see meaningful engine name")
        XCTAssertEqual(alternateEngine.displayName, "Parakeet", "Engine name should be recognizable")
        
        // User does a test recording with new engine
        appState.toggleRecording()
        XCTAssertTrue(appState.isRecording, "User should be able to record with new engine")
        appState.toggleRecording()
        
        // Switch back for cleanup
        appState.switchSpeechEngine(to: originalEngine)
        XCTAssertEqual(appState.currentSpeechEngine, originalEngine, "Should switch back successfully")
    }
    
    // Test user workflow: User interacts with transcription display
    func testUserInteractsWithTranscriptionDisplay() {
        // User starts with empty transcription area
        XCTAssertEqual(appState.transcriptionText, "", "User sees empty transcription initially")
        
        // Simulate user receiving transcription result
        let testResults = [
            "Hello world",
            "This is a test of the transcription system",
            "The user should see this text clearly"
        ]
        
        for result in testResults {
            // Simulate transcription result appearing (as user would see)
            appState.transcriptionText = result
            XCTAssertEqual(appState.transcriptionText, result, "User should see transcription result: '\(result)'")
            
            // User starts new recording (simulating clicking record button)
            appState.toggleRecording()
            XCTAssertEqual(appState.transcriptionText, "", "New recording should clear text for user")
            
            // User stops recording
            appState.toggleRecording()
        }
    }
    
    // Test user workflow: User configures clipboard setting
    func testUserConfiguresClipboardSetting() {
        // Default should be OFF
        XCTAssertFalse(appState.copyToClipboard, "Clipboard copy should default to OFF")

        // User enables clipboard in settings
        appState.copyToClipboard = true
        XCTAssertTrue(appState.copyToClipboard, "User should be able to enable clipboard copy")

        // Setting should persist
        let persisted = UserDefaults.standard.bool(forKey: "copyToClipboard")
        XCTAssertTrue(persisted, "Clipboard setting should persist for next launch")

        // User disables clipboard in settings
        appState.copyToClipboard = false
        XCTAssertFalse(appState.copyToClipboard, "User should be able to disable clipboard copy")

        let persistedOff = UserDefaults.standard.bool(forKey: "copyToClipboard")
        XCTAssertFalse(persistedOff, "Clipboard OFF setting should persist")
    }

    // Test user workflow: Accessibility notification when clipboard is disabled
    func testAccessibilityNotificationWithClipboardDisabled() {
        // Ensure clipboard is disabled (default)
        appState.copyToClipboard = false

        // Accessibility notification should be observable
        XCTAssertFalse(appState.showAccessibilityNotification, "Should not show initially")

        // When clipboard is disabled and no accessibility, app should show accessibility notification
        appState.showAccessibilityNotification = true
        XCTAssertTrue(appState.showAccessibilityNotification, "Should show accessibility notification")

        // User taps to dismiss
        appState.hideAccessibilityNotification()
        XCTAssertFalse(appState.showAccessibilityNotification, "Should dismiss accessibility notification")
    }

    // Test user workflow: User sees accessibility permission status
    func testUserSeesAccessibilityPermissionStatus() {
        // User should be able to see their permission status
        let permissionStatus = appState.hasAccessibilityPermission
        XCTAssertNotNil(permissionStatus, "User should see permission status")
        
        // User updates permission check (simulating refreshing UI)
        appState.updateAccessibilityPermission()
        
        // User should still see valid permission status
        XCTAssertNotNil(appState.hasAccessibilityPermission, "Permission status should remain available")
        
        // User should see their hotkey regardless of permission status
        let hotkey = appState.getCurrentShortcutString()
        XCTAssertFalse(hotkey.isEmpty, "User should always see their hotkey")
    }
    
    // Test user workflow: User performs rapid interactions (stress test)
    func testUserPerformsRapidInteractions() async {
        // User rapidly clicks buttons (simulating quick user interactions)
        for i in 0..<5 {
            // User clicks record
            appState.toggleRecording()
            XCTAssertTrue(appState.isRecording, "Recording should start on click \(i+1)")
            
            // Brief moment as user realizes they want to stop
            try? await Task.sleep(for: .milliseconds(20))
            
            // User clicks stop
            appState.toggleRecording()
            XCTAssertFalse(appState.isRecording, "Recording should stop on click \(i+1)")
            
            // Brief pause between attempts
            try? await Task.sleep(for: .milliseconds(10))
        }
        
        // App should remain stable for user
        XCTAssertNotNil(appState, "App should remain stable after rapid interactions")
        XCTAssertFalse(appState.isRecording, "Should not be recording after rapid test")
    }
    
    // Test user workflow: User sees audio level feedback during recording
    func testUserSeesAudioLevelFeedbackDuringRecording() async {
        var audioLevels: [Float] = []
        
        // User observes audio level display (simulating UI binding)
        let cancellable = appState.$currentAudioLevel
            .sink { level in audioLevels.append(level) }
        
        // User starts recording to see audio levels
        appState.toggleRecording()
        
        // Give time for audio system to provide levels
        try? await Task.sleep(for: .milliseconds(100))
        
        // User stops recording
        appState.toggleRecording()
        
        // User should have seen audio level updates
        XCTAssertGreaterThan(audioLevels.count, 0, "User should see audio level updates")
        
        // All levels should be valid for user display
        for level in audioLevels {
            XCTAssertGreaterThanOrEqual(level, 0, "Audio levels should be valid for user")
        }
        
        cancellable.cancel()
    }
    
    // Test user workflow: User manages listening indicator visibility
    func testUserManagesListeningIndicatorVisibility() {
        // User starts with no indicator
        XCTAssertFalse(appState.showListeningIndicator, "User should not see indicator initially")
        
        // User starts recording and sees indicator
        appState.toggleRecording()
        XCTAssertTrue(appState.showListeningIndicator, "User should see indicator when recording")
        
        // User manually hides indicator (simulating UI button click)
        appState.hideListeningIndicator()
        XCTAssertFalse(appState.showListeningIndicator, "User should be able to hide indicator")
        
        // User stops recording
        appState.toggleRecording()
        XCTAssertFalse(appState.isRecording, "Recording should stop normally")
    }
    
    // Test user workflow: User's preferences persist across sessions
    func testUserPreferencesPersistAcrossSessions() async {
        let originalEngine = appState.currentSpeechEngine
        // Only parakeet engine is available now
        let newEngine: SpeechEngineType = .parakeet
        
        // User changes engine preference (simulating menu selection)
        appState.switchSpeechEngine(to: newEngine)
        
        // User's choice should be saved for next session
        let savedPreference = UserDefaults.standard.string(forKey: "speechEngine")
        XCTAssertEqual(savedPreference, newEngine.rawValue, "User's engine choice should be saved")
        
        // User does a quick recording with their chosen engine
        appState.toggleRecording()
        try? await Task.sleep(for: .milliseconds(50))
        appState.toggleRecording()
        
        // User's engine choice should still be active
        XCTAssertEqual(appState.currentSpeechEngine, newEngine, "User's engine choice should remain active")
        
        // Clean up
        appState.switchSpeechEngine(to: originalEngine)
    }
    
    // Test user workflow: User experiences complete transcription cycle
    func testUserExperiencesCompleteTranscriptionCycle() async {
        // 1. User sees clean initial state
        XCTAssertFalse(appState.isRecording, "User starts with no recording")
        XCTAssertEqual(appState.transcriptionText, "", "User starts with empty text")
        
        // 2. User initiates recording (button click)
        appState.toggleRecording()
        XCTAssertTrue(appState.isRecording, "User sees recording started")
        XCTAssertTrue(appState.showListeningIndicator, "User sees listening feedback")
        
        // 3. User records for a moment
        try? await Task.sleep(for: .milliseconds(100))
        
        // 4. User stops recording (button click)
        appState.toggleRecording()
        XCTAssertFalse(appState.isRecording, "User sees recording stopped")
        
        // 5. Give time for processing (user waits)
        try? await Task.sleep(for: .milliseconds(200))
        
        // 6. User should see stable app state after complete cycle
        XCTAssertNotNil(appState, "App should remain stable after complete workflow")
        XCTAssertFalse(appState.isRecording, "Should not be recording after workflow")
        
        // Note: Transcription text may be empty due to short/invalid audio, which is expected behavior
    }
    
    // Test bug reproduction: Long recording duration breaks subsequent recordings
    func testLongRecordingBreaksSubsequentRecordings() async {
        // Test the reported bug where recordings longer than 15 seconds break dictation
        
        // First verify short recording works
        appState.toggleRecording()
        XCTAssertTrue(appState.isRecording, "Short recording should start normally")
        
        // Record for less than 10 seconds (this should work)
        try? await Task.sleep(for: .milliseconds(200))
        
        appState.toggleRecording()
        XCTAssertFalse(appState.isRecording, "Short recording should stop normally")
        
        // Wait for processing
        try? await Task.sleep(for: .milliseconds(300))
        
        // Now test long recording (simulating >15 second recording)
        appState.toggleRecording()
        XCTAssertTrue(appState.isRecording, "Long recording should start normally")
        
        // Simulate recording for more than 15 seconds
        // Since we can't actually record for 15+ seconds in a test, 
        // we'll simulate the audio recorder being active for longer
        try? await Task.sleep(for: .milliseconds(500))
        
        appState.toggleRecording()
        XCTAssertFalse(appState.isRecording, "Long recording should stop")
        
        // Wait for processing - this is where the bug might manifest
        try? await Task.sleep(for: .milliseconds(500))
        
        // Now test if subsequent recordings work (this is where the bug appears)
        appState.toggleRecording()
        XCTAssertTrue(appState.isRecording, "Subsequent recording should start after long recording")
        
        try? await Task.sleep(for: .milliseconds(200))
        
        appState.toggleRecording()
        XCTAssertFalse(appState.isRecording, "Subsequent recording should stop normally")
        
        // Verify the app is still in a usable state
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertNotNil(appState.audioRecorder, "Audio recorder should still exist after long recording")
        XCTAssertFalse(appState.isRecording, "Should not be stuck in recording state")
    }
    
    // Test resource cleanup after multiple recordings
    func testResourceCleanupAfterMultipleRecordings() async {
        // This test checks if temporary files and audio resources are properly cleaned up
        let initialRecorder = appState.audioRecorder
        
        // Perform multiple recording cycles
        for i in 0..<5 {
            appState.toggleRecording()
            XCTAssertTrue(appState.isRecording, "Recording \(i+1) should start")
            
            // Simulate variable recording durations
            let duration = i % 2 == 0 ? 100 : 300 // Alternate between short and longer recordings
            try? await Task.sleep(for: .milliseconds(duration))
            
            appState.toggleRecording()
            XCTAssertFalse(appState.isRecording, "Recording \(i+1) should stop")
            
            // Wait for processing between recordings
            try? await Task.sleep(for: .milliseconds(200))
        }
        
        // Verify the audio recorder is still the same instance (not recreated due to errors)
        XCTAssertTrue(appState.audioRecorder === initialRecorder, "Audio recorder should not be recreated due to errors")
        XCTAssertFalse(appState.isRecording, "Should not be in recording state after all tests")
    }
}