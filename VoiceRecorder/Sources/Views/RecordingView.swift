import SwiftUI

// MARK: - Waveform Visualization View

/// A view that displays animated vertical bars representing audio levels
struct WaveformView: View {
    let audioLevel: Float
    let isActive: Bool
    let barCount: Int

    @State private var levelHistory: [Float] = []
    @State private var animationTimer: Timer?

    init(audioLevel: Float, isActive: Bool, barCount: Int = 24) {
        self.audioLevel = audioLevel
        self.isActive = isActive
        self.barCount = barCount
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.1), value: levelHistory)
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
        .onChange(of: audioLevel) { newLevel in
            if isActive {
                updateLevelHistory(with: newLevel)
            }
        }
        .onChange(of: isActive) { active in
            if active {
                startWaveformAnimation()
            } else {
                stopWaveformAnimation()
            }
        }
        .onAppear {
            initializeLevelHistory()
            if isActive {
                startWaveformAnimation()
            }
        }
        .onDisappear {
            stopWaveformAnimation()
        }
    }

    private func initializeLevelHistory() {
        levelHistory = Array(repeating: 0.0, count: barCount)
    }

    private func updateLevelHistory(with level: Float) {
        var history = levelHistory
        history.removeFirst()
        history.append(level)
        levelHistory = history
    }

    private func startWaveformAnimation() {
        // Timer to shift levels even when no new audio level arrives
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            if isActive {
                // Shift the history to create movement effect
                var history = levelHistory
                if history.count > 0 {
                    history.removeFirst()
                    history.append(audioLevel)
                    Task { @MainActor in
                        levelHistory = history
                    }
                }
            }
        }
    }

    private func stopWaveformAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        // Reset to flat line
        levelHistory = Array(repeating: 0.0, count: barCount)
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard index < levelHistory.count else { return 4 }
        let level = CGFloat(levelHistory[index])
        // Minimum height of 4, maximum of 36 (leaving padding)
        return 4 + level * 32
    }

    private func barColor(for index: Int) -> Color {
        guard index < levelHistory.count else { return .gray.opacity(0.3) }
        let level = levelHistory[index]

        if level > 0.8 {
            return .red
        } else if level > 0.5 {
            return .orange
        } else if level > 0.1 {
            return .green
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// MARK: - Recording View

struct RecordingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Microphone picker
            microphonePickerView

            Divider()

            // Transcript display
            transcriptView

            Divider()

            // Waveform visualization
            waveformSection

            // Controls
            controlsView

            Divider()

            // Footer with additional actions
            footerView
        }
        .sheet(isPresented: $appState.showingAddTranscript) {
            AddTranscriptView()
        }
        .onAppear {
            appState.checkReferenceRecording()
            // Set default device if none selected
            if appState.selectedDevice == nil {
                appState.selectedDevice = appState.availableDevices.first
            }
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

            // Reference Voice Recording
            referenceVoiceButton

            Button(action: { appState.showingAddTranscript = true }) {
                Label("Add", systemImage: "plus")
            }
        }
        .padding()
    }

    private var referenceVoiceButton: some View {
        HStack(spacing: 4) {
            Button(action: toggleReferenceRecording) {
                Label(appState.isRecordingReference ? "Stop" : "Ref Voice",
                      systemImage: appState.isRecordingReference ? "stop.circle.fill" : "waveform")
                    .foregroundColor(appState.isRecordingReference ? .red : .primary)
            }
            .buttonStyle(.bordered)
            .tint(appState.isRecordingReference ? .red : nil)
            .disabled(appState.isRecording || appState.isPlaying)

            if appState.hasReferenceRecording {
                Button(action: {
                    if appState.isPlaying {
                        appState.stopPlaying()
                    } else {
                        appState.playReferenceRecording()
                    }
                }) {
                    Image(systemName: appState.isPlaying ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.bordered)
                .disabled(appState.isRecording || appState.isRecordingReference)

                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var microphonePickerView: some View {
        HStack {
            Image(systemName: "mic.fill")
                .foregroundColor(.secondary)

            Text("Microphone:")
                .foregroundColor(.secondary)

            Picker("Microphone", selection: $appState.selectedDevice) {
                Text("System Default").tag(nil as AudioInputDevice?)
                ForEach(appState.availableDevices) { device in
                    Text(device.name).tag(device as AudioInputDevice?)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 300)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .disabled(appState.isRecording || appState.isRecordingReference)
    }

    private var waveformSection: some View {
        VStack(spacing: 4) {
            if appState.isRecording || appState.isRecordingReference {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(appState.isRecording || appState.isRecordingReference ? 1.0 : 0.0)
                    Text("Recording...")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            WaveformView(
                audioLevel: appState.audioLevel,
                isActive: appState.isRecording || appState.isRecordingReference
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
    
    private var footerView: some View {
        HStack {
            // Download button
            Button(action: appState.downloadAsZip) {
                Label("Download ZIP", systemImage: "arrow.down.doc.fill")
            }
            .buttonStyle(.bordered)
            .disabled(appState.isRecording || appState.isRecordingReference)

            Spacer()

            // Exit button
            Button(action: appState.exitApp) {
                Label("Finish & Exit", systemImage: "xmark.circle.fill")
            }
            .buttonStyle(.bordered)
            .tint(appState.allTranscriptsRecorded ? .green : nil)
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

    private func toggleReferenceRecording() {
        if appState.isRecordingReference {
            appState.stopRecordingReference()
        } else {
            appState.startRecordingReference()
        }
    }
}

