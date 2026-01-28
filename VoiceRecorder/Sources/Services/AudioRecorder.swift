import AVFoundation
import Combine
import CoreAudio
import Foundation

/// Represents an available audio input device
struct AudioInputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let uid: String
}

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var audioPlayer: AVAudioPlayer?
    private var playbackCompletion: (() -> Void)?
    private var levelTimer: Timer?

    /// Currently selected audio input device ID. Set before calling startRecording.
    /// If nil, uses the system default input device.
    var selectedDeviceID: AudioDeviceID?

    /// Published audio level (0.0-1.0 normalized) updated at ~60Hz during recording
    @Published private(set) var audioLevel: Float = 0.0

    // MARK: - Device Enumeration

    /// Returns a list of available audio input devices
    static func availableInputDevices() -> [AudioInputDevice] {
        var devices: [AudioInputDevice] = []

        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Get the size of the device list
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )

        guard status == noErr else { return devices }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        // Get the device IDs
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )

        guard status == noErr else { return devices }

        // Filter for input devices and get their names
        for deviceID in deviceIDs {
            // Check if device has input channels
            var inputChannelsAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var inputSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(deviceID, &inputChannelsAddress, 0, nil, &inputSize)

            guard status == noErr, inputSize > 0 else { continue }

            let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferListPointer.deallocate() }

            status = AudioObjectGetPropertyData(deviceID, &inputChannelsAddress, 0, nil, &inputSize, bufferListPointer)
            guard status == noErr else { continue }

            let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
            let hasInputChannels = bufferList.reduce(0) { $0 + Int($1.mNumberChannels) } > 0

            guard hasInputChannels else { continue }

            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
            var nameRef: Unmanaged<CFString>?
            status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &nameRef)
            let name = (status == noErr && nameRef != nil) ? (nameRef!.takeUnretainedValue() as String) : "Unknown Device"

            // Get device UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
            var uidRef: Unmanaged<CFString>?
            status = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uidRef)
            let uid = (status == noErr && uidRef != nil) ? (uidRef!.takeUnretainedValue() as String) : "\(deviceID)"

            devices.append(AudioInputDevice(id: deviceID, name: name, uid: uid))
        }

        return devices
    }

    /// Returns the system default input device
    static func defaultInputDevice() -> AudioInputDevice? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        guard status == noErr else { return nil }

        return availableInputDevices().first { $0.id == deviceID }
    }

    // MARK: - Device Selection

    /// Sets the input device for the audio engine
    private func setInputDevice(_ deviceID: AudioDeviceID, for engine: AVAudioEngine) throws {
        let inputNode = engine.inputNode
        let audioUnit = inputNode.audioUnit!

        var deviceIDVar = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDVar,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status != noErr {
            throw NSError(
                domain: "AudioRecorder",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Failed to set audio input device"]
            )
        }
    }

    // MARK: - Recording

    func startRecording(to url: URL) throws {
        // Create output directory if needed
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Configure audio session (macOS doesn't need explicit session config like iOS)
        let audioEngine = AVAudioEngine()

        // Set the selected input device if specified
        if let deviceID = selectedDeviceID {
            try setInputDevice(deviceID, for: audioEngine)
        }

        let inputNode = audioEngine.inputNode

        // Get the native format (must be done after setting the device)
        let nativeFormat = inputNode.inputFormat(forBus: 0)

        // Define our target format: 44100Hz, 16-bit, mono
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 44100,
            channels: 1,
            interleaved: true
        ) else {
            throw NSError(domain: "AudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create target format"])
        }

        // Create the audio file with WAV format
        let audioFile = try AVAudioFile(
            forWriting: url,
            settings: targetFormat.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )

        // Create converter from native format to target format
        guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat) else {
            throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
        }

        // Install tap on input node - also calculate audio levels
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self, weak audioFile] buffer, _ in
            guard let audioFile = audioFile else { return }

            // Calculate RMS level from buffer for audio metering
            self?.calculateLevel(from: buffer)

            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / nativeFormat.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .haveData || status == .inputRanDry {
                do {
                    try audioFile.write(from: convertedBuffer)
                } catch {
                    print("Error writing audio: \(error)")
                }
            }
        }

        try audioEngine.start()

        self.audioEngine = audioEngine
        self.audioFile = audioFile

        // Start audio level timer for UI updates at ~60Hz
        startLevelTimer()
    }

    func stopRecording() {
        stopLevelTimer()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        audioLevel = 0.0
    }

    // MARK: - Audio Level Monitoring

    /// Current RMS level calculated from audio buffer (used internally)
    private var currentRMSLevel: Float = 0.0
    private let levelLock = NSLock()

    /// Calculates the RMS level from an audio buffer
    private func calculateLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataPointer = channelData[0]
        let frameLength = Int(buffer.frameLength)

        guard frameLength > 0 else { return }

        // Calculate RMS (Root Mean Square)
        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelDataPointer[i]
            sum += sample * sample
        }
        let rms = sqrtf(sum / Float(frameLength))

        // Convert RMS to dB
        let minDb: Float = -60.0 // Minimum dB threshold
        let db = 20.0 * log10f(max(rms, 0.000001))

        // Normalize from dB range to 0.0-1.0
        // Map minDb...0 dB to 0.0...1.0
        let normalizedLevel = max(0.0, min(1.0, (db - minDb) / (-minDb)))

        levelLock.lock()
        currentRMSLevel = normalizedLevel
        levelLock.unlock()
    }

    /// Starts a timer to publish audio levels at ~60Hz
    private func startLevelTimer() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let level: Float
            if self.audioPlayer?.isPlaying == true {
                // Playback mode: get levels from AVAudioPlayer
                self.audioPlayer?.updateMeters()
                let dB = self.audioPlayer?.averagePower(forChannel: 0) ?? -160.0
                // Convert dB to linear (0.0-1.0): pow(10, dB / 20), then clamp
                let linear = pow(10.0, dB / 20.0)
                level = max(0.0, min(1.0, linear))
            } else {
                // Recording mode: use the RMS level from the audio buffer
                self.levelLock.lock()
                level = self.currentRMSLevel
                self.levelLock.unlock()
            }

            DispatchQueue.main.async {
                self.audioLevel = level
            }
        }
    }

    /// Stops the audio level timer
    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    func playRecording(from url: URL, completion: @escaping () -> Void) throws {
        stopPlaying()

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.isMeteringEnabled = true
        audioPlayer?.delegate = self
        playbackCompletion = completion
        audioPlayer?.play()
        startLevelTimer()
    }
    
    func stopPlaying() {
        stopLevelTimer()
        audioPlayer?.stop()
        audioPlayer = nil
        playbackCompletion = nil
        audioLevel = 0.0
    }
}

extension AudioRecorder: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playbackCompletion?()
        playbackCompletion = nil
    }
}

