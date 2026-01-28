import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Transcript display
            transcriptView
            
            Divider()
            
            // Controls
            controlsView
        }
        .sheet(isPresented: $appState.showingAddTranscript) {
            AddTranscriptView()
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Voice: \(appState.voiceName)")
                    .font(.headline)
                Text("Progress: \(appState.progressText)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Circle()
                    .fill(appState.currentTranscript?.isRecorded == true ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                Text("\(appState.recordedCount) recorded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: { appState.showingAddTranscript = true }) {
                Label("Add", systemImage: "plus")
            }
        }
        .padding()
    }
    
    private var transcriptView: some View {
        VStack(spacing: 16) {
            if let transcript = appState.currentTranscript {
                Text(transcript.filename)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView {
                    Text(transcript.text)
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
            } else {
                Text("No transcripts found")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
    
    private var controlsView: some View {
        VStack(spacing: 16) {
            // Playback and recording controls
            HStack(spacing: 24) {
                // Play button
                Button(action: togglePlayback) {
                    Label(appState.isPlaying ? "Stop" : "Play", 
                          systemImage: appState.isPlaying ? "stop.fill" : "play.fill")
                }
                .disabled(appState.currentTranscript?.isRecorded != true || appState.isRecording)
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                // Record button
                Button(action: toggleRecording) {
                    Label(appState.isRecording ? "Stop Recording" : "Record",
                          systemImage: appState.isRecording ? "stop.circle.fill" : "mic.fill")
                        .foregroundColor(appState.isRecording ? .red : .primary)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(appState.isRecording ? .red : .accentColor)
                .disabled(appState.isPlaying)
            }
            
            // Navigation controls
            HStack(spacing: 24) {
                Button(action: appState.goToPrevious) {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(appState.currentIndex == 0 || appState.isRecording)
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Button(action: appState.goToNext) {
                    Label("Next", systemImage: "chevron.right")
                }
                .disabled(appState.currentIndex >= appState.transcripts.count - 1 || appState.isRecording)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }
        }
        .padding()
    }
    
    private func toggleRecording() {
        if appState.isRecording {
            appState.stopRecording()
        } else {
            appState.startRecording()
        }
    }
    
    private func togglePlayback() {
        if appState.isPlaying {
            appState.stopPlaying()
        } else {
            appState.playRecording()
        }
    }
}

