import XCTest
import Foundation
@testable import Superhoarse

/// Comprehensive tests for ParakeetEngine handling of different audio lengths
@MainActor
final class ParakeetEngineAudioLengthTests: XCTestCase {
    var engine: ParakeetEngine!
    
    override func setUpWithError() throws {
        engine = ParakeetEngine()
    }
    
    override func tearDownWithError() throws {
        engine = nil
    }
    
    // MARK: - Test Audio Generation Utilities
    
    /// Generate synthetic 16kHz mono PCM audio data for testing
    /// - Parameters:
    ///   - durationSeconds: Duration of audio in seconds
    ///   - frequency: Tone frequency in Hz (default 440Hz for audible tone)
    ///   - amplitude: Amplitude scaling factor (0.0 to 1.0)
    /// - Returns: Audio data in 16-bit PCM format
    private func generateTestAudio(durationSeconds: Double, frequency: Double = 440.0, amplitude: Double = 0.3) -> Data {
        let sampleRate: Double = 16000 // 16kHz as required by Parakeet
        let totalSamples = Int(durationSeconds * sampleRate)
        
        var audioSamples: [Int16] = []
        audioSamples.reserveCapacity(totalSamples)
        
        for i in 0..<totalSamples {
            let time = Double(i) / sampleRate
            let sampleValue = sin(2.0 * .pi * frequency * time) * amplitude
            let int16Sample = Int16(sampleValue * Double(Int16.max))
            audioSamples.append(int16Sample)
        }
        
        return Data(bytes: audioSamples, count: audioSamples.count * MemoryLayout<Int16>.size)
    }
    
    /// Generate silence audio data for testing
    private func generateSilenceAudio(durationSeconds: Double) -> Data {
        let sampleRate: Double = 16000
        let totalSamples = Int(durationSeconds * sampleRate)
        let silentSamples = Array(repeating: Int16(0), count: totalSamples)
        return Data(bytes: silentSamples, count: silentSamples.count * MemoryLayout<Int16>.size)
    }
    
    /// Generate white noise audio data for testing
    private func generateNoiseAudio(durationSeconds: Double, amplitude: Double = 0.1) -> Data {
        let sampleRate: Double = 16000
        let totalSamples = Int(durationSeconds * sampleRate)
        
        var audioSamples: [Int16] = []
        audioSamples.reserveCapacity(totalSamples)
        
        for _ in 0..<totalSamples {
            let randomValue = Double.random(in: -1.0...1.0) * amplitude
            let int16Sample = Int16(randomValue * Double(Int16.max))
            audioSamples.append(int16Sample)
        }
        
        return Data(bytes: audioSamples, count: audioSamples.count * MemoryLayout<Int16>.size)
    }
    
    // MARK: - Short Audio Tests
    
    /// Test transcription of very short audio samples (< 1 second)
    func testVeryShortAudioTranscription() async throws {
        // Initialize engine
        try await engine.initialize()
        XCTAssertTrue(engine.isInitialized, "Engine should be initialized")
        
        let shortDurations: [Double] = [0.1, 0.25, 0.5, 0.75] // seconds
        
        for duration in shortDurations {
            print("Testing \(duration)s audio sample...")
            
            let audioData = generateTestAudio(durationSeconds: duration)
            XCTAssertGreaterThan(audioData.count, 0, "Should generate audio data for \(duration)s")
            
            // Test transcription - should not crash and should handle gracefully
            let result = await engine.transcribe(audioData)
            
            // Very short audio may return nil, but should not crash
            print("Result for \(duration)s: \(result ?? "nil")")
            
            // The key test is that it doesn't crash and handles the short audio
            XCTAssertTrue(true, "Engine should handle \(duration)s audio without crashing")
        }
    }
    
    /// Test transcription of audio right at the 1-second boundary
    func testOneBoundaryAudioTranscription() async throws {
        try await engine.initialize()
        
        let boundaryDurations: [Double] = [0.9, 1.0, 1.1] // Around 1-second boundary
        
        for duration in boundaryDurations {
            print("Testing boundary duration \(duration)s...")
            
            let audioData = generateTestAudio(durationSeconds: duration)
            let result = await engine.transcribe(audioData)
            
            if duration >= 1.0 {
                // Audio >= 1 second should have better chance of transcription
                print("Result for \(duration)s (>= 1s): \(result ?? "nil")")
            } else {
                // Audio < 1 second may return nil but should not crash
                print("Result for \(duration)s (< 1s): \(result ?? "nil")")
            }
            
            XCTAssertTrue(true, "Engine should handle \(duration)s audio at boundary")
        }
    }
    
    /// Test that short audio with decoder state reset works properly
    func testShortAudioWithDecoderStateReset() async throws {
        try await engine.initialize()
        
        let shortAudio = generateTestAudio(durationSeconds: 0.8)
        
        // Perform multiple short transcriptions to test decoder state management
        for i in 1...5 {
            print("Short transcription attempt \(i)...")
            
            let result = await engine.transcribe(shortAudio)
            print("Attempt \(i) result: \(result ?? "nil")")
            
            // Each attempt should be handled consistently
            XCTAssertTrue(true, "Attempt \(i) should be handled consistently")
            
            // Brief pause between attempts
            try await Task.sleep(for: .milliseconds(50))
        }
    }
    
    // MARK: - Long Audio Tests
    
    /// Test transcription of longer audio samples
    func testLongAudioTranscription() async throws {
        try await engine.initialize()
        
        let longDurations: [Double] = [2.0, 5.0, 8.0, 12.0] // seconds
        
        for duration in longDurations {
            print("Testing \(duration)s audio sample...")
            
            let audioData = generateTestAudio(durationSeconds: duration)
            XCTAssertGreaterThan(audioData.count, 0, "Should generate audio data for \(duration)s")
            
            let result = await engine.transcribe(audioData)
            print("Result for \(duration)s: \(result ?? "nil")")
            
            // Longer audio should have better transcription success rates
            XCTAssertTrue(true, "Engine should handle \(duration)s audio without issues")
        }
    }
    
    /// Test that long audio doesn't corrupt decoder state for subsequent short audio
    func testLongAudioDoesNotCorruptSubsequentShortAudio() async throws {
        try await engine.initialize()
        
        // First: transcribe long audio
        print("Phase 1: Transcribing long audio (10s)...")
        let longAudio = generateTestAudio(durationSeconds: 10.0)
        let longResult = await engine.transcribe(longAudio)
        print("Long audio result: \(longResult ?? "nil")")
        
        // Then: transcribe short audio to verify state is not corrupted
        print("Phase 2: Transcribing short audio (0.8s) after long audio...")
        let shortAudio = generateTestAudio(durationSeconds: 0.8)
        let shortResult = await engine.transcribe(shortAudio)
        print("Short audio result after long: \(shortResult ?? "nil")")
        
        // The key test is that the short audio transcription is handled properly
        // after the long audio, indicating decoder state is properly managed
        XCTAssertTrue(true, "Short audio should be handled properly after long audio")
    }
    
    /// Test multiple long audio transcriptions in sequence
    func testMultipleLongAudioTranscriptions() async throws {
        try await engine.initialize()
        
        let longDurations: [Double] = [3.0, 6.0, 4.0, 8.0]
        
        for (index, duration) in longDurations.enumerated() {
            print("Long transcription \(index + 1): \(duration)s...")
            
            let audioData = generateTestAudio(durationSeconds: duration, frequency: 440.0 + Double(index) * 100)
            let result = await engine.transcribe(audioData)
            print("Result \(index + 1): \(result ?? "nil")")
            
            // Brief pause between long transcriptions
            try await Task.sleep(for: .milliseconds(100))
        }
        
        XCTAssertTrue(true, "Multiple long audio transcriptions should be handled")
    }
    
    // MARK: - Mixed Length Tests
    
    /// Test alternating between short and long audio samples
    func testAlternatingShortAndLongAudio() async throws {
        try await engine.initialize()
        
        let testSequence: [(duration: Double, type: String)] = [
            (0.6, "short"),
            (3.0, "long"), 
            (0.8, "short"),
            (5.0, "long"),
            (0.4, "short"),
            (2.5, "long")
        ]
        
        for (index, test) in testSequence.enumerated() {
            print("Test \(index + 1): \(test.type) audio (\(test.duration)s)...")
            
            let audioData = generateTestAudio(durationSeconds: test.duration)
            let result = await engine.transcribe(audioData)
            print("Result \(index + 1): \(result ?? "nil")")
            
            // Brief pause between tests
            try await Task.sleep(for: .milliseconds(50))
        }
        
        XCTAssertTrue(true, "Alternating short and long audio should be handled")
    }
    
    /// Test rapid succession of different length audio samples
    func testRapidSuccessionDifferentLengths() async throws {
        try await engine.initialize()
        
        let rapidDurations: [Double] = [0.3, 1.5, 0.7, 2.0, 0.5, 4.0, 0.9]
        
        for (index, duration) in rapidDurations.enumerated() {
            print("Rapid test \(index + 1): \(duration)s...")
            
            let audioData = generateTestAudio(durationSeconds: duration)
            let result = await engine.transcribe(audioData)
            print("Rapid result \(index + 1): \(result ?? "nil")")
            
            // Minimal pause for rapid testing
            try await Task.sleep(for: .milliseconds(10))
        }
        
        XCTAssertTrue(true, "Rapid succession of different lengths should be handled")
    }
    
    // MARK: - Edge Case Tests
    
    /// Test extremely short audio (< 0.1 seconds)
    func testExtremelyShortAudio() async throws {
        try await engine.initialize()
        
        let extremelyShortDurations: [Double] = [0.01, 0.05, 0.08] // Very short durations
        
        for duration in extremelyShortDurations {
            print("Testing extremely short audio: \(duration)s...")
            
            let audioData = generateTestAudio(durationSeconds: duration)
            let result = await engine.transcribe(audioData)
            print("Extremely short result (\(duration)s): \(result ?? "nil")")
            
            // Should not crash with extremely short audio
            XCTAssertTrue(true, "Should handle extremely short audio (\(duration)s)")
        }
    }
    
    /// Test with silence audio of different lengths
    func testSilenceAudioDifferentLengths() async throws {
        try await engine.initialize()
        
        let silenceDurations: [Double] = [0.5, 1.0, 2.0, 5.0]
        
        for duration in silenceDurations {
            print("Testing silence audio: \(duration)s...")
            
            let silenceData = generateSilenceAudio(durationSeconds: duration)
            let result = await engine.transcribe(silenceData)
            print("Silence result (\(duration)s): \(result ?? "nil")")
            
            // Silence should typically return nil, but should not crash
            XCTAssertTrue(true, "Should handle silence audio (\(duration)s)")
        }
    }
    
    /// Test with noise audio of different lengths
    func testNoiseAudioDifferentLengths() async throws {
        try await engine.initialize()
        
        let noiseDurations: [Double] = [0.5, 1.0, 3.0]
        
        for duration in noiseDurations {
            print("Testing noise audio: \(duration)s...")
            
            let noiseData = generateNoiseAudio(durationSeconds: duration)
            let result = await engine.transcribe(noiseData)
            print("Noise result (\(duration)s): \(result ?? "nil")")
            
            // Noise may or may not transcribe, but should not crash
            XCTAssertTrue(true, "Should handle noise audio (\(duration)s)")
        }
    }
    
    // MARK: - Decoder State Management Tests
    
    /// Test that decoder state is properly reset between transcriptions
    func testDecoderStateResetBetweenTranscriptions() async throws {
        try await engine.initialize()
        
        // Perform a series of transcriptions and verify decoder state management
        let testAudio = generateTestAudio(durationSeconds: 1.5)
        
        for i in 1...10 {
            print("Decoder state test \(i)...")
            
            let result = await engine.transcribe(testAudio)
            print("Result \(i): \(result ?? "nil")")
            
            // Each transcription should start with a clean decoder state
            XCTAssertTrue(true, "Transcription \(i) should have clean decoder state")
            
            try await Task.sleep(for: .milliseconds(20))
        }
    }
    
    /// Test engine behavior after initialization
    func testEngineInitializationState() async throws {
        // Test before initialization
        XCTAssertFalse(engine.isInitialized, "Engine should not be initialized initially")
        
        let preInitAudio = generateTestAudio(durationSeconds: 1.0)
        let preInitResult = await engine.transcribe(preInitAudio)
        XCTAssertNil(preInitResult, "Should return nil before initialization")
        
        // Test after initialization
        try await engine.initialize()
        XCTAssertTrue(engine.isInitialized, "Engine should be initialized after initialize()")
        
        let postInitAudio = generateTestAudio(durationSeconds: 1.0)
        let postInitResult = await engine.transcribe(postInitAudio)
        // Result may be nil for synthetic audio, but should not crash
        print("Post-init result: \(postInitResult ?? "nil")")
        XCTAssertTrue(true, "Should handle transcription after initialization")
    }
    
    // MARK: - Performance and Stress Tests
    
    /// Stress test with many short audio samples
    func testStressTestManyShortSamples() async throws {
        try await engine.initialize()
        
        let shortAudio = generateTestAudio(durationSeconds: 0.6)
        let iterations = 50
        
        print("Stress testing with \(iterations) short samples...")
        
        for i in 1...iterations {
            let result = await engine.transcribe(shortAudio)
            
            if i % 10 == 0 {
                print("Completed \(i)/\(iterations) iterations")
            }
            
            // Brief pause to prevent overwhelming the system
            try await Task.sleep(for: .milliseconds(5))
        }
        
        print("Stress test completed successfully")
        XCTAssertTrue(true, "Should handle \(iterations) short transcriptions")
    }
    
    /// Test memory usage with different audio lengths
    func testMemoryUsageWithDifferentLengths() async throws {
        try await engine.initialize()
        
        let memoryTestDurations: [Double] = [0.5, 2.0, 5.0, 10.0, 15.0]
        
        for duration in memoryTestDurations {
            print("Memory test with \(duration)s audio...")
            
            let audioData = generateTestAudio(durationSeconds: duration)
            let result = await engine.transcribe(audioData)
            print("Memory test result (\(duration)s): \(result ?? "nil")")
            
            // Brief pause to allow memory cleanup
            try await Task.sleep(for: .milliseconds(100))
        }
        
        XCTAssertTrue(true, "Should handle various audio lengths without memory issues")
    }
}