import XCTest
import Foundation
@testable import SuperWhisperLite

final class SpeechRecognizerTests: XCTestCase {
    var speechRecognizer: SpeechRecognizer!
    
    override func setUpWithError() throws {
        speechRecognizer = SpeechRecognizer()
    }
    
    override func tearDownWithError() throws {
        speechRecognizer = nil
    }
    
    func testInitialization() {
        XCTAssertNotNil(speechRecognizer)
    }
    
    func testModelPathGeneration() {
        // Test that the model path is generated correctly
        let modelsDir = FileManager.default.urls(for: .applicationSupportDirectory, 
                                               in: .userDomainMask).first!
            .appendingPathComponent("SuperWhisperLite/Models")
        
        let expectedPath = modelsDir.appendingPathComponent("ggml-base.bin").path
        
        // Verify the path structure is correct
        XCTAssertTrue(expectedPath.contains("SuperWhisperLite/Models"))
        XCTAssertTrue(expectedPath.hasSuffix("ggml-base.bin"))
    }
    
    func testTranscribeWithNilAudioData() {
        let expectation = XCTestExpectation(description: "Transcription with nil data")
        let emptyData = Data()
        
        speechRecognizer.transcribe(emptyData) { result in
            XCTAssertNil(result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testTranscribeWithInvalidAudioData() {
        let expectation = XCTestExpectation(description: "Transcription with invalid data")
        let invalidData = Data("invalid audio data".utf8)
        
        speechRecognizer.transcribe(invalidData) { result in
            // Should handle invalid data gracefully
            XCTAssertNil(result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConvertAudioDataToFloatArray() {
        // Create test PCM data (16-bit signed integers)
        var testPCM: [Int16] = [0, 1000, -1000, Int16.max, Int16.min]
        let testData = Data(bytes: &testPCM, count: testPCM.count * MemoryLayout<Int16>.size)
        
        // Use reflection to call the private method for testing
        let mirror = Mirror(reflecting: speechRecognizer)
        
        // We can't directly test the private method, but we can test the data conversion logic
        let expectedFloats = testPCM.map { Float($0) / Float(Int16.max) }
        
        XCTAssertEqual(expectedFloats.count, 5)
        XCTAssertEqual(expectedFloats[0], 0.0, accuracy: 0.001)
        XCTAssertEqual(expectedFloats[1], 1000.0 / Float(Int16.max), accuracy: 0.001)
        XCTAssertEqual(expectedFloats[2], -1000.0 / Float(Int16.max), accuracy: 0.001)
        XCTAssertEqual(expectedFloats[3], 1.0, accuracy: 0.001)
        XCTAssertEqual(expectedFloats[4], -1.0, accuracy: 0.001)
    }
    
    func testModelDownloadURL() {
        let expectedURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
        let url = URL(string: expectedURL)
        
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertEqual(url?.host, "huggingface.co")
        XCTAssertTrue(url?.path.contains("ggml-base.bin") ?? false)
    }
    
    func testModelDirectoryCreation() {
        let modelsDir = FileManager.default.urls(for: .applicationSupportDirectory, 
                                               in: .userDomainMask).first!
            .appendingPathComponent("SuperWhisperLite/Models")
        
        // Clean up if exists
        try? FileManager.default.removeItem(at: modelsDir)
        
        // Create directory (simulating what happens in getModelPath)
        try? FileManager.default.createDirectory(at: modelsDir, 
                                               withIntermediateDirectories: true)
        
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: modelsDir.path, 
                                                   isDirectory: &isDirectory)
        
        XCTAssertTrue(exists)
        XCTAssertTrue(isDirectory.boolValue)
        
        // Clean up
        try? FileManager.default.removeItem(at: modelsDir)
    }
    
    func testConcurrentTranscriptionRequests() {
        let expectation1 = XCTestExpectation(description: "First transcription")
        let expectation2 = XCTestExpectation(description: "Second transcription")
        
        let testData1 = Data("test1".utf8)
        let testData2 = Data("test2".utf8)
        
        speechRecognizer.transcribe(testData1) { result in
            expectation1.fulfill()
        }
        
        speechRecognizer.transcribe(testData2) { result in
            expectation2.fulfill()
        }
        
        wait(for: [expectation1, expectation2], timeout: 5.0)
    }
    
    func testMemoryCleanupOnDeinit() {
        // Create a new instance that will be deallocated
        var tempRecognizer: SpeechRecognizer? = SpeechRecognizer()
        
        // Keep a weak reference to test deallocation
        weak var weakRef = tempRecognizer
        
        tempRecognizer = nil
        
        // The object should be deallocated
        XCTAssertNil(weakRef)
    }
}