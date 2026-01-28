import SwiftUI
import AppKit

@main
struct VoiceRecorderApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Force the app to the foreground - required for SwiftUI apps run via SPM
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 600, minHeight: 500)
        }
    }
}

