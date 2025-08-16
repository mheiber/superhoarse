import XCTest
import Foundation
import Combine
@testable import Superhoarse

/// Focused tests to reproduce the exact dictation bug: recordings > 10 seconds break subsequent recordings
@MainActor
final class DictationBugReproductionTests: XCTestCase {
    var appState: AppState!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        appState = AppState.shared
        cancellables = Set<AnyCancellable>()
        
        // Ensure clean state
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
    
    // MARK: - Direct Bug Reproduction Tests
    
    /// Reproduce the exact reported bug: >10 second dictation breaks subsequent recordings
    func testLongDictationBreaksSubsequentRecordings() async {
        print("=== Testing Long Dictation Bug Reproduction ===")
        
        // Phase 1: Verify short recordings work normally
        print("Phase 1: Testing short recording baseline...")
        
        let shortResult = await performRecordingCycle(duration: 200) // 200ms
        XCTAssertTrue(shortResult.recordingSucceeded, "Short recording should succeed")
        XCTAssertFalse(appState.isRecording, "Should not be recording after short cycle")
        
        // Phase 2: Perform the problematic long recording (>10 seconds)
        print("Phase 2: Testing long recording (>10 seconds)...")
        
        let longResult = await performRecordingCycle(duration: 12000) // 12 seconds
        print("Long recording result: succeeded=\(longResult.recordingSucceeded), finalState=\(longResult.finalRecordingState)")
        
        // Phase 3: Test if subsequent recordings are broken
        print("Phase 3: Testing subsequent recordings after long recording...")
        
        let subsequentResults = await performMultipleRecordingCycles(count: 3, duration: 200)
        
        for (index, result) in subsequentResults.enumerated() {
            print("Subsequent recording \(index + 1): succeeded=\(result.recordingSucceeded)")
            XCTAssertTrue(result.recordingSucceeded, "Subsequent recording \(index + 1) should work after long recording")
        }
        
        // Final verification
        XCTAssertFalse(appState.isRecording, "App should not be stuck in recording state")
        XCTAssertNotNil(appState.audioRecorder, "Audio recorder should still exist")
    }
    
    /// Test the exact 10-second threshold
    func testTenSecondThreshold() async {
        print("=== Testing 10-Second Threshold ===")
        
        let testDurations = [
            (name: "9 seconds", duration: 9000),   // Just under threshold
            (name: "10 seconds", duration: 10000), // At threshold  
            (name: "11 seconds", duration: 11000), // Just over threshold
            (name: "15 seconds", duration: 15000)  // Well over threshold
        ]
        
        for test in testDurations {
            print("Testing \(test.name)...")
            
            // Perform the test recording
            let result = await performRecordingCycle(duration: test.duration)
            print("\(test.name) recording: succeeded=\(result.recordingSucceeded)")
            
            // Test subsequent recording
            let subsequentResult = await performRecordingCycle(duration: 200)
            print("Subsequent after \(test.name): succeeded=\(subsequentResult.recordingSucceeded)")
            
            XCTAssertTrue(subsequentResult.recordingSucceeded, 
                         "Subsequent recording should work after \(test.name) recording")
            
            // Reset state between tests
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
    
    /// Test different speech engines to see if bug is engine-specific
    func testBugAcrossDifferentEngines() async {
        print("=== Testing Bug Across Different Speech Engines ===")
        
        let engines: [SpeechEngineType] = [.parakeet]
        
        for engine in engines {
            print("Testing with \(engine.displayName)...")
            
            // Switch to the engine
            appState.switchSpeechEngine(to: engine)
            try? await Task.sleep(for: .milliseconds(200)) // Allow engine to initialize
            
            // Test long recording with this engine
            let longResult = await performRecordingCycle(duration: 12000)
            print("\(engine.displayName) long recording: succeeded=\(longResult.recordingSucceeded)")
            
            // Test subsequent recording
            let subsequentResult = await performRecordingCycle(duration: 200)
            print("\(engine.displayName) subsequent: succeeded=\(subsequentResult.recordingSucceeded)")
            
            XCTAssertTrue(subsequentResult.recordingSucceeded, 
                         "Subsequent recording should work with \(engine.displayName)")
        }
    }
    
    // MARK: - Timeout and Processing Tests
    
    /// Test transcription timeout behavior specifically
    func testTranscriptionTimeoutBehavior() async {
        print("=== Testing Transcription Timeout Behavior ===")
        
        // Create audio data that should trigger timeout (simulate very long processing)
        let largeAudioData = createLargeAudioData(durationSeconds: 20)
        
        let startTime = Date()
        var timeoutError: Error?
        
        do {
            // Use the same timeout mechanism as the app
            let result = try await withTimeout(seconds: 30) {
                await appState.currentEngine?.transcribe(largeAudioData)
            }
            print("Transcription completed in \(Date().timeIntervalSince(startTime))s: \(result != nil)")
        } catch {
            timeoutError = error
            print("Transcription timed out after \(Date().timeIntervalSince(startTime))s: \(error)")
        }
        
        // Test if subsequent transcription works after timeout
        let shortAudioData = createSyntheticAudioData(samples: 16000) // 1 second
        let subsequentResult = await appState.currentEngine?.transcribe(shortAudioData)
        
        XCTAssertNotNil(subsequentResult, "Subsequent transcription should work even after timeout")
    }
    
    /// Test memory cleanup after failed long transcriptions
    func testMemoryCleanupAfterFailedTranscription() async {
        print("=== Testing Memory Cleanup After Failed Transcription ===")
        
        // Perform several long recordings that might fail or timeout
        for i in 0..<5 {
            print("Long transcription attempt \(i + 1)...")
            
            let longAudioData = createLargeAudioData(durationSeconds: 15)
            let result = await appState.currentEngine?.transcribe(longAudioData)
            
            print("Attempt \(i + 1) result: \(result != nil ? "Success" : "Failed/Nil")")
            
            // Brief pause between attempts
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        // Test if short transcription still works
        let shortResult = await performRecordingCycle(duration: 200)
        XCTAssertTrue(shortResult.recordingSucceeded, "Short recording should work after memory stress")
    }
    
    // MARK: - State Management Tests
    
    /// Test recording state consistency after long recordings
    func testRecordingStateConsistency() async {
        print("=== Testing Recording State Consistency ===")
        
        // Initial state check
        XCTAssertFalse(appState.isRecording, "Should start not recording")
        XCTAssertFalse(appState.showListeningIndicator, "Should not show indicator initially")
        
        // Perform long recording
        appState.toggleRecording()
        XCTAssertTrue(appState.isRecording, "Should be recording")
        XCTAssertTrue(appState.showListeningIndicator, "Should show indicator")
        
        // Wait for long duration
        try? await Task.sleep(for: .milliseconds(12000)) // 12 seconds
        
        // Stop recording
        appState.toggleRecording()
        XCTAssertFalse(appState.isRecording, "Should stop recording")
        
        // Wait for processing
        try? await Task.sleep(for: .milliseconds(2000))
        
        // Verify clean final state
        XCTAssertFalse(appState.isRecording, "Should not be recording after processing")
        XCTAssertFalse(appState.showListeningIndicator, "Should not show indicator after processing")
        
        // Test that subsequent recordings work
        let subsequentResult = await performRecordingCycle(duration: 200)
        XCTAssertTrue(subsequentResult.recordingSucceeded, "Subsequent recording should work")
    }
    
    // MARK: - Helper Methods
    
    private struct RecordingResult {
        let recordingSucceeded: Bool
        let finalRecordingState: Bool
        let processingTime: TimeInterval
    }
    
    /// Performs a complete recording cycle and returns the result
    private func performRecordingCycle(duration: Int) async -> RecordingResult {
        let startTime = Date()
        
        // Start recording
        appState.toggleRecording()
        let recordingStarted = appState.isRecording
        
        if !recordingStarted {
            return RecordingResult(recordingSucceeded: false, finalRecordingState: false, processingTime: 0)
        }
        
        // Wait for specified duration
        try? await Task.sleep(for: .milliseconds(duration))
        
        // Stop recording
        appState.toggleRecording()
        let finalState = appState.isRecording
        
        // Wait for processing to complete
        try? await Task.sleep(for: .milliseconds(2000))
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return RecordingResult(
            recordingSucceeded: recordingStarted && !finalState,
            finalRecordingState: appState.isRecording,
            processingTime: processingTime
        )
    }
    
    /// Performs multiple recording cycles
    private func performMultipleRecordingCycles(count: Int, duration: Int) async -> [RecordingResult] {
        var results: [RecordingResult] = []
        
        for _ in 0..<count {
            let result = await performRecordingCycle(duration: duration)
            results.append(result)
            
            // Brief pause between recordings
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        return results
    }
    
    /// Creates large audio data for stress testing
    private func createLargeAudioData(durationSeconds: Int) -> Data {
        let sampleRate = 16000
        let totalSamples = sampleRate * durationSeconds
        return createSyntheticAudioData(samples: totalSamples)
    }
    
    /// Creates synthetic audio data for testing
    private func createSyntheticAudioData(samples: Int) -> Data {
        var audioData = Data()
        
        // Create more realistic audio data with some speech-like characteristics
        for i in 0..<samples {
            let time = Double(i) / 16000.0
            
            // Generate speech-like frequency patterns
            let fundamentalFreq = 150.0 + 50.0 * sin(time * 2.0) // Varying fundamental frequency
            let amplitude = 8000.0 * (1.0 + 0.3 * sin(time * 10.0)) // Varying amplitude
            
            // Add harmonics for more realistic sound
            let sample1 = sin(2.0 * Double.pi * fundamentalFreq * time) * amplitude * 0.6
            let sample2 = sin(2.0 * Double.pi * fundamentalFreq * 2.0 * time) * amplitude * 0.3
            let sample3 = sin(2.0 * Double.pi * fundamentalFreq * 3.0 * time) * amplitude * 0.1
            
            let finalSample = Int16(sample1 + sample2 + sample3)
            
            withUnsafeBytes(of: finalSample.littleEndian) { bytes in
                audioData.append(contentsOf: bytes)
            }
        }
        
        return audioData
    }
    
    /// Helper function for timeout testing (copied from AppState)
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
}

struct TimeoutError: Error {
    let message = "Operation timed out"
}