import Foundation

class TranscriptManager {
    let baseURL: URL
    
    var transcriptsURL: URL {
        baseURL.appendingPathComponent("transcripts")
    }
    
    var recordingsURL: URL {
        baseURL.appendingPathComponent("recordings")
    }

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func voiceRecordingsURL(voiceName: String) -> URL {
        recordingsURL.appendingPathComponent(voiceName)
    }

    func referenceRecordingURL(voiceName: String) -> URL {
        voiceRecordingsURL(voiceName: voiceName).appendingPathComponent("ref.wav")
    }
    
    func loadTranscripts(voiceName: String) throws -> [Transcript] {
        // Create transcripts directory if it doesn't exist
        try FileManager.default.createDirectory(at: transcriptsURL, withIntermediateDirectories: true)

        let files = try FileManager.default.contentsOfDirectory(at: transcriptsURL, includingPropertiesForKeys: nil)
        let txtFiles = files.filter { $0.pathExtension.lowercased() == "txt" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        let voiceRecordingsURL = recordingsURL.appendingPathComponent(voiceName)

        return try txtFiles.map { url in
            let text = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            let filename = url.lastPathComponent
            let baseName = (filename as NSString).deletingPathExtension

            // Check for recording with matching base name
            let wavURL = voiceRecordingsURL.appendingPathComponent("\(baseName).wav")
            let isRecorded = FileManager.default.fileExists(atPath: wavURL.path)

            return Transcript(filename: filename, text: text, isRecorded: isRecorded)
        }
    }
    
    func recordingURL(for transcript: Transcript, voiceName: String) -> URL {
        let baseName = transcript.baseName
        return recordingsURL.appendingPathComponent(voiceName).appendingPathComponent("\(baseName).wav")
    }
    
    func transcriptOutputURL(for transcript: Transcript, voiceName: String) -> URL {
        let baseName = transcript.baseName
        return recordingsURL.appendingPathComponent(voiceName).appendingPathComponent("\(baseName).txt")
    }
    
    func copyTranscriptToRecordings(_ transcript: Transcript, voiceName: String) throws {
        let outputURL = transcriptOutputURL(for: transcript, voiceName: voiceName)
        let directory = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try transcript.text.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    
    func addNewTranscript(name: String, text: String) throws -> Transcript {
        try FileManager.default.createDirectory(at: transcriptsURL, withIntermediateDirectories: true)
        
        // Sanitize filename
        let sanitizedName = name.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let filename = "\(sanitizedName).txt"
        let url = transcriptsURL.appendingPathComponent(filename)
        
        try text.write(to: url, atomically: true, encoding: .utf8)
        
        return Transcript(filename: filename, text: text, isRecorded: false)
    }
}

