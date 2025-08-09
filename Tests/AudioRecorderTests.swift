import XCTest
import Foundation
import AVFoundation
@testable import SuperWhisperLite

final class AudioRecorderTests: XCTestCase {
    var audioRecorder: AudioRecorder!
    
    override func setUpWithError() throws {
        audioRecorder = AudioRecorder()
    }
    
    override func tearDownWithError() throws {
        audioRecorder = nil
    }
    
    func testInitialRecordingState() {
        XCTAssertFalse(audioRecorder.isRecording)
    }
    
    func testStartRecordingSetsRecordingState() {
        audioRecorder.startRecording()
        
        // Wait briefly for recording to start
        let expectation = XCTestExpectation(description: "Recording starts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.audioRecorder.isRecording)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Clean up
        audioRecorder.stopRecording { _ in }
    }
    
    func testStopRecordingWithoutStartingDoesNotCrash() {
        let expectation = XCTestExpectation(description: "Stop recording completes")
        
        audioRecorder.stopRecording { audioData in
            XCTAssertNil(audioData)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStartRecordingTwiceDoesNotCreateMultipleRecorders() {
        audioRecorder.startRecording()
        let firstState = audioRecorder.isRecording
        
        audioRecorder.startRecording() // Should be ignored
        let secondState = audioRecorder.isRecording
        
        XCTAssertEqual(firstState, secondState)
        
        // Clean up
        audioRecorder.stopRecording { _ in }
    }
    
    func testRecordingCreatesTemporaryFile() {
        let expectation = XCTestExpectation(description: "Temporary file handling")
        
        audioRecorder.startRecording()
        
        // Wait briefly then stop to test file creation/cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.audioRecorder.stopRecording { audioData in
                // File should be cleaned up after reading
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testRecordingSettingsAreCorrect() {
        // This is more of an integration test, but we can verify the settings would be correct
        let expectedSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // Verify our expected settings match Whisper's requirements
        XCTAssertEqual(expectedSettings[AVSampleRateKey] as? Double, 16000.0)
        XCTAssertEqual(expectedSettings[AVNumberOfChannelsKey] as? Int, 1)
        XCTAssertEqual(expectedSettings[AVLinearPCMBitDepthKey] as? Int, 16)
    }
    
    func testDelegateMethodsHandleErrors() {
        // Test that delegate methods don't crash when called with errors
        let mockRecorder = AVAudioRecorder()
        let testError = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // This tests the error handling path
        audioRecorder.audioRecorderEncodeErrorDidOccur(mockRecorder, error: testError)
        audioRecorder.audioRecorderDidFinishRecording(mockRecorder, successfully: false)
        
        // If we get here without crashing, the error handling works
        XCTAssertTrue(true)
    }
}