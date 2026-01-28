import AVFoundation
import Foundation

class AudioRecorder: NSObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var audioPlayer: AVAudioPlayer?
    private var playbackCompletion: (() -> Void)?
    
    func startRecording(to url: URL) throws {
        // Create output directory if needed
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Configure audio session (macOS doesn't need explicit session config like iOS)
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        
        // Get the native format
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
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak audioFile] buffer, _ in
            guard let audioFile = audioFile else { return }
            
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
    }
    
    func stopRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
    }
    
    func playRecording(from url: URL, completion: @escaping () -> Void) throws {
        stopPlaying()
        
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        playbackCompletion = completion
        audioPlayer?.play()
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackCompletion = nil
    }
}

extension AudioRecorder: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playbackCompletion?()
        playbackCompletion = nil
    }
}

