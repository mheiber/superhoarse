import Foundation
import AVFoundation
import os.log

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    // AVAudioSession is not available on macOS, using AVAudioEngine instead
    private var recordingURL: URL?
    private var completionHandler: ((Data?) -> Void)?
    
    @Published var currentAudioLevel: Float = 0.0
    private var levelTimer: Timer?
    private let logger = Logger(subsystem: "com.superwhisper.lite", category: "AudioRecorder")
    
    override init() {
        super.init()
        setupRecordingSession()
    }
    
    private func setupRecordingSession() {
        #if os(macOS)
        // Request microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if !granted {
                    print("Microphone access denied")
                }
            }
        case .denied, .restricted:
            print("Microphone access denied or restricted")
        @unknown default:
            break
        }
        #endif
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        // Create temporary file URL
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
        
        guard let url = recordingURL else { return }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,  // Whisper prefers 16kHz
            AVNumberOfChannelsKey: 1,   // Mono
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            startLevelMonitoring()
            
            // Remove verbose logging - not needed for normal operation
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording(completion: @escaping (Data?) -> Void) {
        guard isRecording else { 
            completion(nil)
            return 
        }
        
        stopLevelMonitoring()
        completionHandler = completion
        audioRecorder?.stop()
    }
    
    var isRecording: Bool {
        return audioRecorder?.isRecording ?? false
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard flag, let url = recordingURL else {
            completionHandler?(nil)
            return
        }
        
        do {
            let audioData = try Data(contentsOf: url)
            // Pass both data and cleanup URL to completion handler
            completionHandler?(audioData)
            
            // Schedule cleanup after a delay to ensure transcription process has finished
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) { [weak self] in
                do {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                        // File cleanup successful - no logging needed
                    }
                } catch {
                    self?.logger.error("Failed to clean up temporary audio file: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to read audio file: \(error.localizedDescription)")
            completionHandler?(nil)
            
            // Still try to clean up the file even if reading failed
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio recording error: \(error?.localizedDescription ?? "Unknown error")")
        completionHandler?(nil)
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        currentAudioLevel = 0.0
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Convert decibel power to a linear scale (0.0 to 1.0)
        // averagePower ranges from -160 (silence) to 0 (maximum)
        let normalizedLevel = max(0.0, (averagePower + 50.0) / 50.0)
        
        DispatchQueue.main.async {
            self.currentAudioLevel = normalizedLevel
        }
    }
}