import Foundation
import SwiftUI
import AppKit
import CoreAudio
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var voiceName: String = ""
    @Published var isVoiceNameSet: Bool = false
    @Published var transcripts: [Transcript] = []
    @Published var currentIndex: Int = 0
    @Published var isRecording: Bool = false
    @Published var isPlaying: Bool = false
    @Published var errorMessage: String?
    @Published var showingAddTranscript: Bool = false
    @Published var newTranscriptText: String = ""
    @Published var newTranscriptName: String = ""
    @Published var isRecordingReference: Bool = false
    @Published var hasReferenceRecording: Bool = false

    /// Currently selected audio input device
    @Published var selectedDevice: AudioInputDevice?

    /// Current audio level (0.0-1.0) - forwarded from audioRecorder via Combine
    @Published private(set) var audioLevel: Float = 0.0

    var transcriptManager: TranscriptManager?
    var audioRecorder: AudioRecorder?
    private var cancellables = Set<AnyCancellable>()

    /// Available audio input devices
    var availableDevices: [AudioInputDevice] {
        AudioRecorder.availableInputDevices()
    }
    
    var currentTranscript: Transcript? {
        guard !transcripts.isEmpty, currentIndex >= 0, currentIndex < transcripts.count else { return nil }
        return transcripts[currentIndex]
    }
    
    var progressText: String {
        guard !transcripts.isEmpty else { return "No transcripts" }
        return "\(currentIndex + 1) of \(transcripts.count)"
    }
    
    var recordedCount: Int {
        transcripts.filter { $0.isRecorded }.count
    }
    
    var allTranscriptsRecorded: Bool {
        !transcripts.isEmpty && transcripts.allSatisfy { $0.isRecorded }
    }

    func setupManagers(baseURL: URL) {
        transcriptManager = TranscriptManager(baseURL: baseURL)
        audioRecorder = AudioRecorder()

        // Forward audio level updates from AudioRecorder to this @Published property
        audioRecorder?.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
    }

    func checkReferenceRecording() {
        guard let manager = transcriptManager else { return }
        let refURL = manager.referenceRecordingURL(voiceName: voiceName)
        hasReferenceRecording = FileManager.default.fileExists(atPath: refURL.path)
    }
    
    func loadTranscripts() {
        guard let manager = transcriptManager else { return }
        do {
            transcripts = try manager.loadTranscripts(voiceName: voiceName)
        } catch {
            errorMessage = "Failed to load transcripts: \(error.localizedDescription)"
        }
    }
    
    func goToNext() {
        if currentIndex < transcripts.count - 1 {
            currentIndex += 1
        }
    }
    
    func goToPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }
    
    func startRecording() {
        guard let recorder = audioRecorder, let transcript = currentTranscript else { return }
        guard let manager = transcriptManager else { return }

        // Set selected device ID before recording
        recorder.selectedDeviceID = selectedDevice?.id

        let wavURL = manager.recordingURL(for: transcript, voiceName: voiceName)
        do {
            try recorder.startRecording(to: wavURL)
            isRecording = true
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        guard let recorder = audioRecorder, let transcript = currentTranscript else { return }
        guard let manager = transcriptManager else { return }
        
        recorder.stopRecording()
        isRecording = false
        
        // Copy transcript text to output directory
        do {
            try manager.copyTranscriptToRecordings(transcript, voiceName: voiceName)
            if let idx = transcripts.firstIndex(where: { $0.id == transcript.id }) {
                transcripts[idx].isRecorded = true
            }
        } catch {
            errorMessage = "Failed to save transcript: \(error.localizedDescription)"
        }
    }
    
    func playRecording() {
        guard let recorder = audioRecorder, let transcript = currentTranscript else { return }
        guard let manager = transcriptManager else { return }
        
        let wavURL = manager.recordingURL(for: transcript, voiceName: voiceName)
        guard FileManager.default.fileExists(atPath: wavURL.path) else {
            errorMessage = "No recording found"
            return
        }
        
        do {
            try recorder.playRecording(from: wavURL) { [weak self] in
                Task { @MainActor in
                    self?.isPlaying = false
                }
            }
            isPlaying = true
        } catch {
            errorMessage = "Failed to play: \(error.localizedDescription)"
        }
    }
    
    func stopPlaying() {
        audioRecorder?.stopPlaying()
        isPlaying = false
    }
    
    func addNewTranscript() {
        guard let manager = transcriptManager else { return }
        guard !newTranscriptName.isEmpty, !newTranscriptText.isEmpty else {
            errorMessage = "Please enter both name and text"
            return
        }

        do {
            let transcript = try manager.addNewTranscript(name: newTranscriptName, text: newTranscriptText)
            transcripts.append(transcript)
            currentIndex = transcripts.count - 1
            newTranscriptName = ""
            newTranscriptText = ""
            showingAddTranscript = false
        } catch {
            errorMessage = "Failed to add transcript: \(error.localizedDescription)"
        }
    }

    // MARK: - Reference Voice Recording

    func startRecordingReference() {
        // Guard against re-entry from SwiftUI re-render during stop
        guard !hasReferenceRecording else { return }
        guard let recorder = audioRecorder, let manager = transcriptManager else { return }

        // Set selected device ID before recording
        recorder.selectedDeviceID = selectedDevice?.id

        let refURL = manager.referenceRecordingURL(voiceName: voiceName)
        do {
            try recorder.startRecording(to: refURL)
            isRecordingReference = true
        } catch {
            errorMessage = "Failed to start reference recording: \(error.localizedDescription)"
        }
    }

    func stopRecordingReference() {
        guard let recorder = audioRecorder else { return }

        recorder.stopRecording()
        hasReferenceRecording = true
        isRecordingReference = false
    }

    func playReferenceRecording() {
        guard let recorder = audioRecorder, let manager = transcriptManager else { return }

        let refURL = manager.referenceRecordingURL(voiceName: voiceName)
        guard FileManager.default.fileExists(atPath: refURL.path) else {
            errorMessage = "No reference recording found"
            return
        }

        do {
            try recorder.playRecording(from: refURL) { [weak self] in
                Task { @MainActor in
                    self?.isPlaying = false
                }
            }
            isPlaying = true
        } catch {
            errorMessage = "Failed to play reference: \(error.localizedDescription)"
        }
    }

    // MARK: - Download as ZIP

    func downloadAsZip() {
        guard let manager = transcriptManager else { return }

        let voiceDir = manager.voiceRecordingsURL(voiceName: voiceName)

        guard FileManager.default.fileExists(atPath: voiceDir.path) else {
            errorMessage = "No recordings directory found"
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Save Recordings ZIP"
        savePanel.nameFieldStringValue = "\(voiceName).zip"
        savePanel.allowedContentTypes = [.zip]
        savePanel.canCreateDirectories = true

        savePanel.begin { [weak self] response in
            guard response == .OK, let destURL = savePanel.url else { return }

            Task { @MainActor in
                self?.createZipArchive(from: voiceDir, to: destURL)
            }
        }
    }

    private func createZipArchive(from sourceDir: URL, to destURL: URL) {
        // Remove existing file if present
        try? FileManager.default.removeItem(at: destURL)

        // Use ditto command to create ZIP archive (reliable on macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", sourceDir.path, destURL.path]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                // Success - open the destination folder in Finder
                NSWorkspace.shared.selectFile(destURL.path, inFileViewerRootedAtPath: destURL.deletingLastPathComponent().path)
            } else {
                errorMessage = "Failed to create ZIP archive"
            }
        } catch {
            errorMessage = "Failed to create ZIP: \(error.localizedDescription)"
        }
    }

    // MARK: - Exit App

    func exitApp() {
        NSApplication.shared.terminate(nil)
    }
}

