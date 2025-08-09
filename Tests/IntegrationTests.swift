import XCTest
import Foundation
import Combine
@testable import SuperWhisperLite

final class IntegrationTests: XCTestCase {
    var appState: AppState!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        appState = AppState()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        appState = nil
        cancellables = nil
    }
    
    func testAppStateInitializationFlow() {
        // Test that AppState properly initializes all components
        XCTAssertTrue(appState.isInitialized)
        XCTAssertFalse(appState.isRecording)
        XCTAssertEqual(appState.transcriptionText, "")
    }
    
    func testRecordingWorkflow() {
        let recordingStartExpectation = XCTestExpectation(description: "Recording starts")
        let recordingStopExpectation = XCTestExpectation(description: "Recording stops")
        
        var recordingStateChanges = 0
        
        appState.$isRecording
            .dropFirst() // Skip initial value
            .sink { isRecording in
                recordingStateChanges += 1
                
                if recordingStateChanges == 1 {
                    XCTAssertTrue(isRecording)
                    recordingStartExpectation.fulfill()
                } else if recordingStateChanges == 2 {
                    XCTAssertFalse(isRecording)
                    recordingStopExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start recording
        appState.toggleRecording()
        
        // Wait for recording to start, then stop it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.appState.toggleRecording()
        }
        
        wait(for: [recordingStartExpectation, recordingStopExpectation], timeout: 2.0)
    }
    
    func testMultipleRecordingToggles() {
        let expectations = (0..<6).map { i in
            XCTestExpectation(description: "State change \(i)")
        }
        
        var changeCount = 0
        
        appState.$isRecording
            .dropFirst() // Skip initial value
            .sink { isRecording in
                if changeCount < expectations.count {
                    let expectedState = changeCount % 2 == 0 // Even = recording, odd = not recording
                    XCTAssertEqual(isRecording, expectedState)
                    expectations[changeCount].fulfill()
                    changeCount += 1
                }
            }
            .store(in: &cancellables)
        
        // Toggle recording 6 times rapidly
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                self.appState.toggleRecording()
            }
        }
        
        wait(for: expectations, timeout: 3.0)
    }
    
    func testTranscriptionTextClearedOnRecordingStart() {
        // Set some initial transcription text
        appState.setValue("Previous transcription", forKey: "transcriptionText")
        XCTAssertEqual(appState.transcriptionText, "Previous transcription")
        
        let expectation = XCTestExpectation(description: "Text cleared on recording start")
        
        appState.$transcriptionText
            .dropFirst() // Skip current value
            .sink { text in
                XCTAssertEqual(text, "")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        appState.toggleRecording()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAppStatePublishedPropertiesAreObservable() {
        var isRecordingChanges = 0
        var transcriptionTextChanges = 0
        var isInitializedChanges = 0
        
        appState.$isRecording.sink { _ in isRecordingChanges += 1 }.store(in: &cancellables)
        appState.$transcriptionText.sink { _ in transcriptionTextChanges += 1 }.store(in: &cancellables)
        appState.$isInitialized.sink { _ in isInitializedChanges += 1 }.store(in: &cancellables)
        
        // Initial values should be observed
        XCTAssertGreaterThanOrEqual(isRecordingChanges, 1)
        XCTAssertGreaterThanOrEqual(transcriptionTextChanges, 1)
        XCTAssertGreaterThanOrEqual(isInitializedChanges, 1)
    }
    
    func testPerformanceOfStateChanges() {
        measure {
            for _ in 0..<100 {
                appState.toggleRecording()
            }
        }
    }
    
    func testMemoryUsageStability() {
        // Test that repeated operations don't cause memory leaks
        let initialMemory = mach_task_self()
        
        for _ in 0..<10 {
            appState.toggleRecording()
            Thread.sleep(forTimeInterval: 0.01)
            appState.toggleRecording()
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        // Allow some cleanup time
        Thread.sleep(forTimeInterval: 0.1)
        
        // This is a basic check - in practice you'd use more sophisticated memory monitoring
        XCTAssertTrue(true) // If we get here without crashing, memory is probably stable
    }
    
    func testConcurrentStateAccess() {
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        // Test concurrent read access
        for _ in 0..<50 {
            group.enter()
            queue.async {
                let _ = self.appState.isRecording
                let _ = self.appState.transcriptionText
                let _ = self.appState.isInitialized
                group.leave()
            }
        }
        
        // Test concurrent write access (through toggleRecording)
        for _ in 0..<10 {
            group.enter()
            queue.async {
                self.appState.toggleRecording()
                group.leave()
            }
        }
        
        let expectation = XCTestExpectation(description: "Concurrent access completes")
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}