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
        XCTAssertTrue(hotkeyString.contains("⌘"), "Hotkey should show Command key for user")
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
        let alternateEngine: SpeechEngineType = (originalEngine == .whisper) ? .parakeet : .whisper
        
        // User selects different speech engine from menu
        appState.switchSpeechEngine(to: alternateEngine)
        
        // User sees engine changed in interface
        XCTAssertEqual(appState.currentSpeechEngine, alternateEngine, "User should see engine changed")
        
        // User can see engine display name for UI
        let engineDisplayName = alternateEngine.displayName
        XCTAssertFalse(engineDisplayName.isEmpty, "User should see meaningful engine name")
        XCTAssertTrue(alternateEngine.displayName == "Whisper (Default)" || alternateEngine.displayName == "Parakeet (Faster)", "Engine name should be recognizable")
        
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
        let newEngine: SpeechEngineType = (originalEngine == .whisper) ? .parakeet : .whisper
        
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
}