import XCTest
import Foundation
import Combine
@testable import SuperWhisperLite

final class AppStateTests: XCTestCase {
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
    
    func testInitialState() {
        XCTAssertFalse(appState.isRecording)
        XCTAssertEqual(appState.transcriptionText, "")
        XCTAssertTrue(appState.isInitialized)
    }
    
    func testToggleRecordingStartsRecording() {
        let expectation = XCTestExpectation(description: "Recording state changes")
        
        appState.$isRecording
            .dropFirst() // Skip initial value
            .sink { isRecording in
                XCTAssertTrue(isRecording)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        appState.toggleRecording()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testToggleRecordingTwiceStopsRecording() {
        appState.toggleRecording() // Start recording
        XCTAssertTrue(appState.isRecording)
        
        let expectation = XCTestExpectation(description: "Recording stops")
        
        appState.$isRecording
            .dropFirst(2) // Skip initial and first toggle
            .sink { isRecording in
                XCTAssertFalse(isRecording)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        appState.toggleRecording() // Stop recording
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testTranscriptionTextUpdates() {
        let expectation = XCTestExpectation(description: "Transcription text updates")
        let expectedText = "Test transcription"
        
        appState.$transcriptionText
            .dropFirst() // Skip initial empty value
            .sink { text in
                XCTAssertEqual(text, expectedText)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate transcription result
        appState.setValue(expectedText, forKey: "transcriptionText")
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStartRecordingClearsTranscriptionText() {
        appState.setValue("Previous text", forKey: "transcriptionText")
        XCTAssertEqual(appState.transcriptionText, "Previous text")
        
        appState.toggleRecording()
        
        XCTAssertEqual(appState.transcriptionText, "")
    }
}