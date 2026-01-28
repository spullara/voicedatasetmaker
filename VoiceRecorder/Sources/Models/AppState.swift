import Foundation
import SwiftUI

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
    
    var transcriptManager: TranscriptManager?
    var audioRecorder: AudioRecorder?
    
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
    
    func setupManagers(baseURL: URL) {
        transcriptManager = TranscriptManager(baseURL: baseURL)
        audioRecorder = AudioRecorder()
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
}

