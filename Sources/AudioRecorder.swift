import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    // AVAudioSession is not available on macOS, using AVAudioEngine instead
    private var recordingURL: URL?
    private var completionHandler: ((Data?) -> Void)?
    
    @Published var currentAudioLevel: Float = 0.0
    private var levelTimer: Timer?
    
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
            
            print("Started recording to: \(url.path)")
        } catch {
            print("Failed to start recording: \(error)")
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
            completionHandler?(audioData)
            
            // Clean up temporary file
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Failed to read audio file: \(error)")
            completionHandler?(nil)
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