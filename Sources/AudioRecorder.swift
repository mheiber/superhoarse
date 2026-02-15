import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox
import os.log

struct AudioInputDevice: Identifiable {
    let name: String
    let uid: String
    var id: String { uid }
}

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var audioConverter: AVAudioConverter?
    private var recordingURL: URL?
    private var completionHandler: ((Data?) -> Void)?

    @Published var currentAudioLevel: Float = 0.0
    private(set) var isRecording = false
    private let logger = Logger(subsystem: "com.superhoarse.lite", category: "AudioRecorder")

    /// The UID of the audio input device to use. nil means system default.
    var selectedDeviceUID: String? = nil

    override init() {
        super.init()
        requestMicrophonePermission()
    }

    private func requestMicrophonePermission() {
        #if os(macOS)
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

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Set the input device if a non-default device is selected.
        // If this fails, we fall back to the system default (no-op).
        if let deviceUID = selectedDeviceUID {
            if !setInputDevice(on: inputNode, deviceUID: deviceUID) {
                logger.warning("Failed to set input device '\(deviceUID)', falling back to system default")
            }
        }

        let hwFormat = inputNode.outputFormat(forBus: 0)

        guard hwFormat.sampleRate > 0, hwFormat.channelCount > 0 else {
            logger.error("Invalid hardware format: rate=\(hwFormat.sampleRate) channels=\(hwFormat.channelCount)")
            return
        }

        // Target format: Float32, 16kHz, mono (intermediate for writing to file)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            logger.error("Failed to create target audio format")
            return
        }

        // Create converter: hardware format -> 16kHz mono Float32
        guard let converter = AVAudioConverter(from: hwFormat, to: targetFormat) else {
            logger.error("Failed to create audio converter")
            return
        }

        // Create temporary file URL
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
        recordingURL = url

        // File format on disk: Int16, 16kHz, mono (what ParakeetEngine expects).
        // Processing format: Float32 (what the converter outputs).
        let fileSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]

        do {
            let file = try AVAudioFile(
                forWriting: url,
                settings: fileSettings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
            self.audioFile = file
            self.audioConverter = converter

            // Install tap on inputNode at hardware format.
            // The tap callback runs on an internal audio thread.
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { [weak self] buffer, _ in
                self?.processTapBuffer(buffer, converter: converter, targetFormat: targetFormat, file: file)
            }

            try engine.start()
            self.audioEngine = engine
            isRecording = true
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            cleanupEngine()
        }
    }

    func stopRecording(completion: @escaping (Data?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }

        // Remove tap and stop engine. After stop() returns, no more tap callbacks fire.
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        isRecording = false

        DispatchQueue.main.async {
            self.currentAudioLevel = 0.0
        }

        // Close file handles
        let url = recordingURL
        audioFile = nil
        audioConverter = nil
        audioEngine = nil

        guard let fileURL = url else {
            completion(nil)
            return
        }

        do {
            let audioData = try Data(contentsOf: fileURL)
            completion(audioData)

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) { [weak self] in
                do {
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        try FileManager.default.removeItem(at: fileURL)
                    }
                } catch {
                    self?.logger.error("Failed to clean up temporary audio file: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to read audio file: \(error.localizedDescription)")
            completion(nil)

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    // MARK: - Tap Buffer Processing

    private func processTapBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat, file: AVAudioFile) {
        calculateAudioLevel(from: buffer)

        // Convert to 16kHz mono Float32
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio))
        guard outputFrameCapacity > 0 else { return }

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            return
        }

        var error: NSError?
        var inputProvided = false
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if inputProvided {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputProvided = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let error = error {
            logger.error("Audio conversion error: \(error.localizedDescription)")
            return
        }

        if convertedBuffer.frameLength > 0 {
            do {
                try file.write(from: convertedBuffer)
            } catch {
                logger.error("Failed to write audio buffer: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Audio Level Calculation

    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }

        let data = channelData[0]
        var sum: Float = 0
        for i in 0..<frames {
            sum += data[i] * data[i]
        }
        let rms = sqrt(sum / Float(frames))

        // Convert to dB and normalize to 0-1 (same scale as previous AVAudioRecorder metering)
        let db = 20 * log10(max(rms, 1e-10))
        let normalizedLevel = max(0.0, (db + 50.0) / 50.0)

        DispatchQueue.main.async {
            self.currentAudioLevel = normalizedLevel
        }
    }

    // MARK: - Device Selection (CoreAudio)

    private func setInputDevice(on inputNode: AVAudioInputNode, deviceUID: String) -> Bool {
        guard let deviceID = audioDeviceID(forUID: deviceUID) else {
            logger.error("No audio device found for UID: \(deviceUID)")
            return false
        }

        guard let audioUnit = inputNode.audioUnit else {
            logger.error("Could not get AudioUnit from input node")
            return false
        }

        var devID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status != noErr {
            logger.error("AudioUnitSetProperty failed with status \(status)")
            return false
        }

        return true
    }

    /// Resolve an AVCaptureDevice.uniqueID to a CoreAudio AudioDeviceID
    /// by enumerating all audio devices and matching UIDs.
    private func audioDeviceID(forUID uid: String) -> AudioDeviceID? {
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: AudioObjectPropertyElement(0)
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress, 0, nil, &dataSize
        ) == noErr, dataSize > 0 else { return nil }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress, 0, nil, &dataSize, &deviceIDs
        ) == noErr else { return nil }

        for deviceID in deviceIDs {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: AudioObjectPropertyElement(0)
            )
            var uidSize: UInt32 = UInt32(MemoryLayout<CFString?>.size)
            var deviceUIDRef: CFString? = nil
            let status = withUnsafeMutablePointer(to: &deviceUIDRef) { ptr in
                AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, ptr)
            }
            if status == noErr, let deviceUID = deviceUIDRef as String?, deviceUID == uid {
                return deviceID
            }
        }
        return nil
    }

    // MARK: - Device Enumeration

    static func availableInputDevices() -> [AudioInputDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        return discovery.devices.map { AudioInputDevice(name: $0.localizedName, uid: $0.uniqueID) }
    }

    private func cleanupEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        audioConverter = nil
        isRecording = false
    }
}
