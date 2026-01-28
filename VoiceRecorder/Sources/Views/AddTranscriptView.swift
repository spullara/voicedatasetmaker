import SwiftUI

struct AddTranscriptView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Transcript")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Filename (without .txt):")
                    .font(.subheadline)
                TextField("e.g., greeting, question_1", text: $appState.newTranscriptName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Transcript Text:")
                    .font(.subheadline)
                TextEditor(text: $appState.newTranscriptText)
                    .frame(minHeight: 100)
                    .border(Color.gray.opacity(0.3))
            }
            
            HStack {
                Button("Cancel") {
                    appState.newTranscriptName = ""
                    appState.newTranscriptText = ""
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button("Add Transcript") {
                    appState.addNewTranscript()
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.newTranscriptName.isEmpty || appState.newTranscriptText.isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

