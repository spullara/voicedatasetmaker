import SwiftUI

struct VoiceNameView: View {
    @EnvironmentObject var appState: AppState
    @State private var baseURL: URL?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Voice Recorder")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Create voice recordings for Qwen3-TTS fine-tuning")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Working Directory:")
                    .font(.headline)
                
                HStack {
                    Text(baseURL?.path ?? "Not selected")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(baseURL == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button("Choose...") {
                        selectDirectory()
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Name:")
                    .font(.headline)
                
                TextField("Enter voice name (e.g., sam, alice)", text: $appState.voiceName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
            }
            
            Text("Transcripts will be loaded from: transcripts/")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Recordings will be saved to: recordings/\(appState.voiceName.isEmpty ? "{voice_name}" : appState.voiceName)/")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: startRecording) {
                Text("Start Recording Session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.voiceName.isEmpty || baseURL == nil)
        }
        .padding(32)
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the directory containing 'transcripts' folder"
        
        if panel.runModal() == .OK {
            baseURL = panel.url
        }
    }
    
    private func startRecording() {
        guard let url = baseURL else { return }
        appState.setupManagers(baseURL: url)
        appState.loadTranscripts()
        appState.isVoiceNameSet = true
    }
}

