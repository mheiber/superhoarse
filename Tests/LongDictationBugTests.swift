import XCTest
import Foundation
import Combine
@testable import Superhoarse

/// Tests to reproduce and diagnose the bug where dictations longer than 10 seconds fail
/// and break subsequent recordings
@MainActor
final class LongDictationBugTests: XCTestCase {
    var appState: AppState!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        appState = AppState.shared
        cancellables = Set<AnyCancellable>()
        
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
        cancellables = nil
    }
    
    // MARK: - Hypothesis 1: Parakeet Audio Context Window Limitation
    
    /// Test that simulates processing audio longer than Parakeet's optimal chunk size (30 seconds)
    func testParakeetChunkSizeLimitation() async {
        // Create a mock long audio recording (simulating 15 seconds at 16kHz)
        let sampleRate: Int = 16000
        let durationSeconds: Int = 15
        let totalSamples = sampleRate * durationSeconds
        
        // Create synthetic audio data
        let audioData = createSyntheticAudioData(samples: totalSamples)
        
        // Test direct transcription with Parakeet engine
        if let parakeetEngine = appState.currentEngine {
            let result = await parakeetEngine.transcribe(audioData)
            
            // The transcription might fail or return nil due to context limitations
            print("Long audio transcription result: \(result ?? "nil")")
            
            // Now test if subsequent short recordings work
            let shortAudioData = createSyntheticAudioData(samples: 32000) // 2 seconds
            let subsequentResult = await parakeetEngine.transcribe(shortAudioData)
            
            XCTAssertNotNil(subsequentResult, "Subsequent transcription should work after long recording")
        } else {
            XCTFail("Parakeet engine should be available")
        }
    }
    
    // MARK: - Hypothesis 2: Transcription Timeout Conflict
    
    /// Test transcription timeout behavior with recordings that take longer to process
    func testTranscriptionTimeoutWithLongAudio() async {
        // Create very long audio data that might exceed processing capabilities
        let longAudioData = createSyntheticAudioData(samples: 320000) // 20 seconds at 16kHz
        
        let expectation = XCTestExpectation(description: "Transcription timeout test")
        var timeoutOccurred = false
        var transcriptionResult: String?
        
        // Start transcription and measure time
        let startTime = Date()
        
        Task {
            transcriptionResult = await appState.currentEngine?.transcribe(longAudioData)
            let duration = Date().timeIntervalSince(startTime)
            
            if duration >= 30.0 {
                timeoutOccurred = true
            }
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 35.0)
        
        // Test subsequent recording after potential timeout
        let shortAudioData = createSyntheticAudioData(samples: 16000) // 1 second
        let subsequentResult = await appState.currentEngine?.transcribe(shortAudioData)
        
        if timeoutOccurred {
            XCTAssertNotNil(subsequentResult, "Subsequent transcription should work even after timeout")
        }
    }
    
    // MARK: - Hypothesis 3: Memory Pressure with Long Audio Arrays
    
    /// Test memory management with multiple long recordings
    func testMemoryPressureWithLongRecordings() async {
        let sampleCount = 160000 // 10 seconds at 16kHz
        var results: [String?] = []
        
        // Perform multiple long transcriptions to build up memory pressure
        for iteration in 0..<5 {
            let audioData = createSyntheticAudioData(samples: sampleCount)
            let result = await appState.currentEngine?.transcribe(audioData)
            results.append(result)
            
            // Allow some time between transcriptions
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        // Test if subsequent short recording works after memory pressure
        let shortAudioData = createSyntheticAudioData(samples: 16000) // 1 second
        let finalResult = await appState.currentEngine?.transcribe(shortAudioData)
        
        XCTAssertNotNil(finalResult, "Should handle subsequent recording after memory pressure")
        
        // Check if any of the long recordings failed (indicating memory issues)
        let failedCount = results.compactMap { $0 }.count
        print("Successful long transcriptions: \(failedCount)/\(results.count)")
    }
    
    // MARK: - Hypothesis 4: Audio File Cleanup Race Condition
    
    /// Test the race condition between file cleanup and transcription processing
    func testAudioFileCleanupRaceCondition() async {
        // This test simulates the timing issue where temporary files are cleaned up
        // while transcription is still processing
        
        var recordingCompletedExpectation = XCTestExpectation(description: "Recording completed")
        var transcriptionResults: [String?] = []
        
        // Start a longer recording that might trigger cleanup race condition
        appState.toggleRecording()
        XCTAssertTrue(appState.isRecording, "Recording should start")
        
        // Simulate recording for a duration that might cause issues
        try? await Task.sleep(for: .milliseconds(500))
        
        appState.toggleRecording()
        XCTAssertFalse(appState.isRecording, "Recording should stop")
        
        // Monitor transcription result
        appState.$transcriptionText
            .dropFirst()
            .sink { result in
                transcriptionResults.append(result.isEmpty ? nil : result)
                recordingCompletedExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [recordingCompletedExpectation], timeout: 35.0)
        
        // Now test subsequent recording
        let subsequentExpectation = XCTestExpectation(description: "Subsequent recording")
        
        appState.toggleRecording()
        try? await Task.sleep(for: .milliseconds(200))
        appState.toggleRecording()
        
        appState.$transcriptionText
            .dropFirst()
            .sink { _ in
                subsequentExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [subsequentExpectation], timeout: 10.0)
        
        XCTAssertFalse(appState.isRecording, "Should not be stuck in recording state")
    }
    
    // MARK: - Hypothesis 5: AVAudioRecorder State Corruption
    
    /// Test if long recordings corrupt the audio recorder state
    func testAudioRecorderStateCorruption() async {
        guard let audioRecorder = appState.audioRecorder else {
            XCTFail("Audio recorder should be available")
            return
        }
        
        let initialRecorder = audioRecorder
        
        // Simulate a long recording cycle
        appState.toggleRecording()
        XCTAssertTrue(appState.isRecording, "Long recording should start")
        
        // Keep recording for longer than typical
        try? await Task.sleep(for: .milliseconds(1000))
        
        appState.toggleRecording()
        XCTAssertFalse(appState.isRecording, "Long recording should stop")
        
        // Wait for processing
        try? await Task.sleep(for: .milliseconds(2000))
        
        // Verify audio recorder is still the same instance and functional
        XCTAssertTrue(appState.audioRecorder === initialRecorder, "Audio recorder should not be recreated")
        XCTAssertFalse(appState.audioRecorder?.isRecording ?? true, "Audio recorder should not be stuck recording")
        
        // Test subsequent recordings
        for i in 0..<3 {
            appState.toggleRecording()
            XCTAssertTrue(appState.isRecording, "Subsequent recording \(i+1) should start")
            
            try? await Task.sleep(for: .milliseconds(100))
            
            appState.toggleRecording()
            XCTAssertFalse(appState.isRecording, "Subsequent recording \(i+1) should stop")
            
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
    
    // MARK: - Edge Case Tests
    
    /// Test the specific 10-second threshold mentioned in the bug report
    func testTenSecondThresholdBehavior() async {
        let testDurations = [8, 10, 12, 15] // seconds
        var results: [String?] = []
        
        for duration in testDurations {
            let audioData = createSyntheticAudioData(samples: 16000 * duration)
            let result = await appState.currentEngine?.transcribe(audioData)
            results.append(result)
            
            print("Duration: \(duration)s, Result: \(result != nil ? "Success" : "Failed")")
            
            // Test subsequent short recording after each duration
            let shortData = createSyntheticAudioData(samples: 16000) // 1 second
            let subsequentResult = await appState.currentEngine?.transcribe(shortData)
            
            XCTAssertNotNil(subsequentResult, "Subsequent transcription should work after \(duration)s recording")
        }
    }
    
    /// Test rapid sequence of long recordings (stress test)
    func testRapidLongRecordingSequence() async {
        for i in 0..<3 {
            appState.toggleRecording()
            XCTAssertTrue(appState.isRecording, "Rapid long recording \(i+1) should start")
            
            // Simulate longer recording
            try? await Task.sleep(for: .milliseconds(800))
            
            appState.toggleRecording()
            XCTAssertFalse(appState.isRecording, "Rapid long recording \(i+1) should stop")
            
            // Brief pause between recordings
            try? await Task.sleep(for: .milliseconds(200))
        }
        
        // Verify final state
        XCTAssertFalse(appState.isRecording, "Should not be stuck in recording state after rapid sequence")
        XCTAssertNotNil(appState.audioRecorder, "Audio recorder should still exist")
    }
    
    // MARK: - Helper Methods
    
    /// Creates synthetic audio data for testing
    private func createSyntheticAudioData(samples: Int) -> Data {
        var audioData = Data()
        
        // Create synthetic PCM data (16-bit signed integers)
        for i in 0..<samples {
            // Generate a simple sine wave with some variation
            let frequency: Double = 440.0 // A4 note
            let amplitude: Double = 16000.0
            let sampleRate: Double = 16000.0
            
            let time = Double(i) / sampleRate
            let value = sin(2.0 * Double.pi * frequency * time) * amplitude
            let sample = Int16(value)
            
            // Convert to little-endian bytes
            withUnsafeBytes(of: sample.littleEndian) { bytes in
                audioData.append(contentsOf: bytes)
            }
        }
        
        return audioData
    }
}