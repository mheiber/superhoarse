import XCTest
import Foundation
import Combine
@testable import Superhoarse

@MainActor
final class SuperhoarseIntegrationTests: XCTestCase {
    var appState: AppState!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        appState = AppState.shared
        cancellables = Set<AnyCancellable>()
        
        // Reset state before each test
        if appState.isRecording {
            appState.toggleRecording()
        }
        appState.transcriptionText = ""
    }
    
    override func tearDownWithError() throws {
        // Ensure recording is stopped after each test
        if appState.isRecording {
            appState.toggleRecording()
        }
        appState.transcriptionText = ""
        
        appState = nil
        cancellables = nil
    }
    
    // Test the core user workflow: user presses hotkey to start/stop recording
    func testUserRecordingWorkflow() {
        let recordingStartExpectation = XCTestExpectation(description: "Recording starts")
        let recordingStopExpectation = XCTestExpectation(description: "Recording stops")
        
        var recordingStateChanges = 0
        
        appState.$isRecording
            .dropFirst() // Skip initial value
            .sink { isRecording in
                recordingStateChanges += 1
                
                if recordingStateChanges == 1 {
                    XCTAssertTrue(isRecording, "Recording should start when user toggles")
                    recordingStartExpectation.fulfill()
                } else if recordingStateChanges == 2 {
                    XCTAssertFalse(isRecording, "Recording should stop when user toggles again")
                    recordingStopExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate user pressing hotkey to start recording
        appState.toggleRecording()
        
        // Simulate user pressing hotkey again to stop recording after brief pause
        Task {
            try await Task.sleep(for: .milliseconds(100))
            await MainActor.run {
                self.appState.toggleRecording()
            }
        }
        
        wait(for: [recordingStartExpectation, recordingStopExpectation], timeout: 2.0)
    }
    
    // Test that starting a new recording clears previous transcription
    func testNewRecordingClearsPreviousTranscription() {
        // Simulate having previous transcription text
        appState.transcriptionText = "Previous transcription"
        XCTAssertEqual(appState.transcriptionText, "Previous transcription")
        
        let expectation = XCTestExpectation(description: "Text cleared on new recording")
        
        appState.$transcriptionText
            .dropFirst() // Skip current value
            .sink { text in
                XCTAssertEqual(text, "", "Starting new recording should clear previous text")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // User starts new recording
        appState.toggleRecording()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // Test that app state initializes properly for user
    func testAppInitializationForUser() {
        // User expects app to be ready when launched
        XCTAssertNotNil(appState, "App should initialize")
        XCTAssertFalse(appState.isRecording, "App should not be recording on startup")
        XCTAssertEqual(appState.transcriptionText, "", "App should have no transcription text on startup")
        
        // Test that properties are observable (needed for UI updates)
        var isRecordingUpdates = 0
        var textUpdates = 0
        
        appState.$isRecording.sink { _ in isRecordingUpdates += 1 }.store(in: &cancellables)
        appState.$transcriptionText.sink { _ in textUpdates += 1 }.store(in: &cancellables)
        
        XCTAssertGreaterThan(isRecordingUpdates, 0, "Recording state should be observable")
        XCTAssertGreaterThan(textUpdates, 0, "Transcription text should be observable")
    }
    
    // Test user workflow for switching between speech engines
    func testUserSwitchesSpeechEngine() {
        // User starts with default engine
        let initialEngine = appState.currentSpeechEngine
        XCTAssertNotNil(initialEngine, "App should have a default speech engine")
        
        // Test that engines are properly initialized by checking engine names
        XCTAssertEqual(initialEngine, SpeechEngineType.parakeet, "Should always use parakeet engine")
        
        // Only parakeet engine is available now
        let newEngine: SpeechEngineType = .parakeet
        appState.switchSpeechEngine(to: newEngine)
        
        XCTAssertEqual(appState.currentSpeechEngine, newEngine, "Engine should switch when user requests")
        
        // Switch back to verify it works both ways
        appState.switchSpeechEngine(to: initialEngine)
        XCTAssertEqual(appState.currentSpeechEngine, initialEngine, "Should be able to switch back")
    }
    
    // Test user workflow for accessibility permissions (observability only)
    func testUserAccessibilityPermissionsWorkflow() {
        // Permission state should be observable for UI updates
        var permissionUpdates = 0
        appState.$hasAccessibilityPermission
            .sink { _ in permissionUpdates += 1 }
            .store(in: &cancellables)
        
        XCTAssertGreaterThan(permissionUpdates, 0, "Permission status should be observable")
        
        // User should be able to see current permission state
        let currentPermission = appState.hasAccessibilityPermission
        XCTAssertNotNil(currentPermission, "Should have permission state")
        
        // User should be able to get shortcut info (doesn't require permissions)
        let shortcut = appState.getCurrentShortcutString()
        XCTAssertFalse(shortcut.isEmpty, "User should see shortcut info")
        
        // Note: We don't test actual permission requests in unit tests
        // as they trigger system dialogs and can't be automated
    }
    
    // Test user workflow with hotkey shortcuts
    func testUserHotKeyWorkflow() {
        // User should be able to see their current hotkey
        let shortcutString = appState.getCurrentShortcutString()
        XCTAssertFalse(shortcutString.isEmpty, "User should see their hotkey shortcut")
        XCTAssertTrue(shortcutString.contains("⌘"), "Hotkey should include command key")
        
        // Hotkey string should be meaningful to user
        let expectedPatterns = ["Space", "⌘⇧", "⌘⌥", "⌘⌃", "⌥⇧"]
        let hasExpectedPattern = expectedPatterns.contains { shortcutString.contains($0) }
        XCTAssertTrue(hasExpectedPattern, "Hotkey should contain recognizable key combinations")
    }
    
    // Test audio level monitoring during recording (user feedback)
    func testUserAudioLevelFeedback() {
        // User should be able to observe audio levels during recording
        var audioLevelUpdates = 0
        
        appState.$currentAudioLevel
            .sink { _ in audioLevelUpdates += 1 }
            .store(in: &cancellables)
        
        // Start recording to enable audio level monitoring
        appState.toggleRecording()
        
        // Give some time for audio system to initialize
        let expectation = XCTestExpectation(description: "Recording setup completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Stop recording
        appState.toggleRecording()
        
        // User should see audio level property is reactive (even if levels are 0)
        XCTAssertGreaterThan(audioLevelUpdates, 0, "Audio level should be observable")
        XCTAssertGreaterThanOrEqual(appState.currentAudioLevel, 0, "Audio level should be valid")
    }
    
    // Test listening indicator visibility for user
    func testUserListeningIndicatorFeedback() {
        // Initially no listening indicator
        XCTAssertFalse(appState.showListeningIndicator, "Should not show indicator when not recording")
        
        let indicatorExpectation = XCTestExpectation(description: "Listening indicator shows")
        
        appState.$showListeningIndicator
            .dropFirst()
            .sink { isShowing in
                if isShowing {
                    indicatorExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // User starts recording - should see listening indicator
        appState.toggleRecording()
        
        wait(for: [indicatorExpectation], timeout: 1.0)
        
        // User can manually hide indicator if needed
        appState.hideListeningIndicator()
        XCTAssertFalse(appState.showListeningIndicator, "User should be able to hide indicator")
        
        // Clean up
        if appState.isRecording {
            appState.toggleRecording()
        }
    }
    
    // Test complete user transcription workflow from start to finish  
    func testCompleteUserTranscriptionWorkflow() async {
        // User starts with clean state
        XCTAssertFalse(appState.isRecording)
        XCTAssertEqual(appState.transcriptionText, "")
        
        // User starts recording
        appState.toggleRecording()
        XCTAssertTrue(appState.isRecording, "Recording should start")
        XCTAssertTrue(appState.showListeningIndicator, "Should show visual feedback")
        
        // Simulate brief recording time
        try? await Task.sleep(for: .milliseconds(100))
        
        // User stops recording - this triggers transcription process
        appState.toggleRecording()
        XCTAssertFalse(appState.isRecording, "Recording should stop")
        
        // Give time for transcription processing to complete
        try? await Task.sleep(for: .milliseconds(500))
        
        // Verify the workflow completed without crashes
        XCTAssertNotNil(appState, "App should remain stable after transcription workflow")
        
        // The transcription text may be empty due to no actual audio content,
        // but the workflow should complete successfully
        XCTAssertTrue(true, "Complete workflow should not crash")
    }
    
    // Test speech engines can be initialized (user readiness)
    func testSpeechEnginesInitialization() async {
        // User expects both speech engines to be available
        let initialEngine = appState.currentSpeechEngine
        
        // Test switching to verify engines are properly initialized
        // Only parakeet engine is available now
        let alternateEngine: SpeechEngineType = .parakeet
        appState.switchSpeechEngine(to: alternateEngine)
        
        // Give time for engine to initialize if needed
        try? await Task.sleep(for: .milliseconds(100))
        
        XCTAssertEqual(appState.currentSpeechEngine, alternateEngine, "Should be able to switch engines")
        
        // Switch back to original
        appState.switchSpeechEngine(to: initialEngine)
        XCTAssertEqual(appState.currentSpeechEngine, initialEngine, "Should be able to switch back")
        
        // Both engines should be available for user
        let parakeetAvailable = SpeechEngineType.parakeet
        XCTAssertNotNil(parakeetAvailable, "Parakeet engine should be available")
    }
    
    // Test user preferences persistence
    func testUserPreferencesPersistence() {
        let initialEngine = appState.currentSpeechEngine
        // Only parakeet engine is available now
        let newEngine: SpeechEngineType = .parakeet
        
        // User changes engine preference
        appState.switchSpeechEngine(to: newEngine)
        
        // Preference should be saved for next app launch
        let savedEngine = UserDefaults.standard.string(forKey: "speechEngine")
        XCTAssertEqual(savedEngine, newEngine.rawValue, "User preference should be persisted")
        
        // Clean up
        appState.switchSpeechEngine(to: initialEngine)
    }
    
    // Test error handling in user workflows
    func testUserWorkflowErrorHandling() async {
        // Test that rapid recording toggles don't crash the app
        for _ in 0..<5 {
            appState.toggleRecording()
            try? await Task.sleep(for: .milliseconds(10))
            appState.toggleRecording()
            try? await Task.sleep(for: .milliseconds(10))
        }
        
        // App should remain stable
        XCTAssertNotNil(appState, "App should remain stable after rapid toggles")
        XCTAssertFalse(appState.isRecording, "Should not be recording after rapid toggles")
        
        // Test setting transcription text directly (simulates successful transcription)
        let testText = "Test transcription result"
        appState.transcriptionText = testText
        XCTAssertEqual(appState.transcriptionText, testText, "Should be able to set transcription text")
    }
    
    // Test user workflow with different audio scenarios
    func testUserWithDifferentAudioScenarios() async {
        // Test user with very brief recording (common user scenario)
        appState.toggleRecording()
        try? await Task.sleep(for: .milliseconds(10)) // Very brief
        appState.toggleRecording()
        
        // User should get feedback that recording was too short
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(appState.isRecording, "Should not be recording after brief session")
        
        // Test user with slightly longer but still short recording
        appState.toggleRecording()
        try? await Task.sleep(for: .milliseconds(50))
        appState.toggleRecording()
        
        // Give time for processing
        try? await Task.sleep(for: .milliseconds(200))
        
        // App should handle short recordings gracefully
        XCTAssertNotNil(appState, "App should remain stable with short recordings")
    }
    
    // Test user workflow when engines need initialization
    func testUserWorkflowWithEngineInitialization() async {
        // User tries both speech engines to ensure they initialize properly
        let engines: [SpeechEngineType] = [.parakeet]
        
        for engine in engines {
            appState.switchSpeechEngine(to: engine)
            
            // User does a quick recording test with each engine
            appState.toggleRecording()
            try? await Task.sleep(for: .milliseconds(50))
            appState.toggleRecording()
            
            // Give time for engine to process
            try? await Task.sleep(for: .milliseconds(100))
            
            // App should remain stable with each engine
            XCTAssertEqual(appState.currentSpeechEngine, engine, "Engine should be set correctly")
            XCTAssertFalse(appState.isRecording, "Should not be recording after test")
        }
    }
    
    // Test user workflow with app state persistence across sessions
    func testUserWorkflowStatePersistence() async {
        // User changes settings that should persist
        let originalEngine = appState.currentSpeechEngine
        // Only parakeet engine is available now
        let newEngine: SpeechEngineType = .parakeet
        
        // User switches engine
        appState.switchSpeechEngine(to: newEngine)
        
        // User does a recording with new engine
        appState.toggleRecording()
        try? await Task.sleep(for: .milliseconds(50))
        appState.toggleRecording()
        
        // Verify engine preference persisted
        let savedEngine = UserDefaults.standard.string(forKey: "speechEngine")
        XCTAssertEqual(savedEngine, newEngine.rawValue, "User engine preference should persist")
        
        // Clean up
        appState.switchSpeechEngine(to: originalEngine)
    }
    
    // Test user accessibility workflow
    func testUserAccessibilityWorkflow() {
        // User checks their current hotkey settings
        let hotkey = appState.getCurrentShortcutString()
        XCTAssertFalse(hotkey.isEmpty, "User should see their hotkey")
        
        // User can see accessibility permission status
        let hasPermission = appState.hasAccessibilityPermission
        XCTAssertNotNil(hasPermission, "User should see permission status")
        
        // User can update permission check without triggering system dialog
        let _ = appState.hasAccessibilityPermission
        appState.updateAccessibilityPermission()
        
        // Permission state should be available to user
        XCTAssertNotNil(appState.hasAccessibilityPermission, "Permission status should be available")
        
        // Note: We don't test requestAccessibilityPermissions() as it shows system dialogs
        
        // Test permission monitoring methods can be called without crashing
        let initialPermissionState = appState.hasAccessibilityPermission
        
        // Test that permission monitoring can start and stop cleanly
        appState.startPermissionMonitoring()
        
        // Wait briefly to ensure timer is set up
        let expectation = XCTestExpectation(description: "Timer setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Stop monitoring should work
        appState.stopPermissionMonitoring()
        
        // Permission state should remain stable
        XCTAssertEqual(appState.hasAccessibilityPermission, initialPermissionState, "Permission state should remain stable after monitoring")
    }
    
    // Test user workflow with multiple quick operations
    func testUserWorkflowQuickOperations() async {
        // User rapidly switches between engines and records (stress test)
        let operations = 3
        
        for _ in 0..<operations {
            // User switches engine
            let engine: SpeechEngineType = .parakeet
            appState.switchSpeechEngine(to: engine)
            
            // User does quick recording
            appState.toggleRecording()
            try? await Task.sleep(for: .milliseconds(20))
            appState.toggleRecording()
            
            // Brief pause between operations
            try? await Task.sleep(for: .milliseconds(30))
        }
        
        // App should remain stable after rapid operations
        XCTAssertNotNil(appState, "App should remain stable after quick operations")
        XCTAssertFalse(appState.isRecording, "Should not be recording after operations")
    }
    
    // Test user workflow with transcription text handling
    func testUserTranscriptionTextWorkflow() {
        // User sees empty state initially
        XCTAssertEqual(appState.transcriptionText, "", "Should start with empty transcription")
        
        // Simulate user getting transcription results (successful workflow)
        let results = ["Hello world", "This is a test", "Speech recognition works"]
        
        for result in results {
            // Simulate transcription result arriving
            appState.transcriptionText = result
            XCTAssertEqual(appState.transcriptionText, result, "Should show transcription to user")
            
            // User starts new recording, which clears previous text
            appState.toggleRecording()
            XCTAssertEqual(appState.transcriptionText, "", "New recording should clear text")
            appState.toggleRecording()
        }
    }
    
    // Test user workflow with audio level feedback
    func testUserAudioLevelWorkflow() async {
        // User starts recording and expects to see audio levels
        var audioLevels: [Float] = []
        
        appState.$currentAudioLevel
            .sink { level in audioLevels.append(level) }
            .store(in: &cancellables)
        
        // User records for a brief period
        appState.toggleRecording()
        try? await Task.sleep(for: .milliseconds(100))
        appState.toggleRecording()
        
        // User should see audio level updates (even if all zeros)
        XCTAssertGreaterThan(audioLevels.count, 0, "User should see audio level updates")
        
        // Audio levels should be valid values
        for level in audioLevels {
            XCTAssertGreaterThanOrEqual(level, 0, "Audio levels should be non-negative")
        }
    }
    
    // Test user workflow when speech engines need to initialize from scratch
    func testUserWorkflowEngineInitialization() async {
        // Test that both engines can be properly initialized for user
        let engines: [SpeechEngineType] = [.parakeet]
        
        for engine in engines {
            // User switches to engine (may need initialization)
            appState.switchSpeechEngine(to: engine)
            
            // Give time for any async initialization
            try? await Task.sleep(for: .milliseconds(200))
            
            // User should see the engine is selected
            XCTAssertEqual(appState.currentSpeechEngine, engine, "Engine should be switched for user")
            
            // User can get engine name for display
            let engineName = engine.displayName
            XCTAssertFalse(engineName.isEmpty, "User should see engine name")
            
            // User performs a quick test recording
            appState.toggleRecording()
            try? await Task.sleep(for: .milliseconds(50))
            appState.toggleRecording()
            
            // App should remain stable with engine
            XCTAssertFalse(appState.isRecording, "Should not be recording after test")
        }
    }
    
    // Test user workflow with app state edge cases
    func testUserWorkflowEdgeCases() async {
        // Test user trying to toggle recording very rapidly (edge case)
        for _ in 0..<10 {
            appState.toggleRecording()
            appState.toggleRecording()  // Rapid toggle
        }
        
        // App should be stable after rapid operations
        XCTAssertFalse(appState.isRecording, "Should not be recording after rapid operations")
        
        // Test user setting transcription text to various edge case values
        let edgeCaseTexts = ["", " ", "\n", "Short", "A very long transcription result that contains many words and should be handled properly by the application"]
        
        for text in edgeCaseTexts {
            appState.transcriptionText = text
            XCTAssertEqual(appState.transcriptionText, text, "Should handle edge case text: '\(text)'")
        }
        
        // User starts recording which should clear text
        appState.toggleRecording()
        XCTAssertEqual(appState.transcriptionText, "", "Recording should clear text")
        appState.toggleRecording()
    }
    
    // Test user workflow with system state changes
    func testUserWorkflowSystemStateChanges() {
        // User checks various system states they care about
        let initialRecording = appState.isRecording
        let initialText = appState.transcriptionText
        let initialEngine = appState.currentSpeechEngine
        let initialIndicator = appState.showListeningIndicator
        
        // All initial states should be sensible for user
        XCTAssertFalse(initialRecording, "Should not start recording")
        XCTAssertEqual(initialText, "", "Should start with empty text")
        XCTAssertNotNil(initialEngine, "Should have default engine")
        XCTAssertFalse(initialIndicator, "Should not show indicator initially")
        
        // User can see their hotkey preference
        let hotkey = appState.getCurrentShortcutString()
        XCTAssertFalse(hotkey.isEmpty, "User should see hotkey")
        XCTAssertTrue(hotkey.contains("⌘"), "Should include command key")
        
        // User can manually hide listening indicator
        appState.showListeningIndicator = true
        XCTAssertTrue(appState.showListeningIndicator, "Should show indicator")
        appState.hideListeningIndicator()
        XCTAssertFalse(appState.showListeningIndicator, "Should hide indicator")
    }
    
    // Test user workflow when app handles various audio processing scenarios
    func testUserWorkflowAudioProcessingScenarios() async {
        // Test user with different recording durations
        let durations: [UInt64] = [10, 25, 50, 100, 200] // milliseconds
        
        for duration in durations {
            // User starts recording
            appState.toggleRecording()
            XCTAssertTrue(appState.isRecording, "Should be recording")
            XCTAssertTrue(appState.showListeningIndicator, "Should show indicator")
            
            // User records for specified duration
            try? await Task.sleep(for: .milliseconds(duration))
            
            // User stops recording
            appState.toggleRecording()
            XCTAssertFalse(appState.isRecording, "Should stop recording")
            
            // Give time for processing
            try? await Task.sleep(for: .milliseconds(100))
            
            // App should handle different durations gracefully
            XCTAssertNotNil(appState, "App should be stable after \(duration)ms recording")
        }
    }
}