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
    
    func loadTranscripts(voiceName: String) throws -> [Transcript] {
        // Create transcripts directory if it doesn't exist
        try FileManager.default.createDirectory(at: transcriptsURL, withIntermediateDirectories: true)
        
        let files = try FileManager.default.contentsOfDirectory(at: transcriptsURL, includingPropertiesForKeys: nil)
        let txtFiles = files.filter { $0.pathExtension.lowercased() == "txt" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        let voiceRecordingsURL = recordingsURL.appendingPathComponent(voiceName)
        
        return try txtFiles.enumerated().map { index, url in
            let text = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            let filename = url.lastPathComponent
            let baseName = (filename as NSString).deletingPathExtension
            
            // Format filename with zero-padded index
            let formattedName = String(format: "%03d_%@", index + 1, baseName)
            let wavURL = voiceRecordingsURL.appendingPathComponent("\(formattedName).wav")
            let isRecorded = FileManager.default.fileExists(atPath: wavURL.path)
            
            return Transcript(filename: filename, text: text, isRecorded: isRecorded)
        }
    }
    
    func recordingURL(for transcript: Transcript, voiceName: String) -> URL {
        guard let index = transcriptIndex(for: transcript) else {
            // Fallback if index not found
            let baseName = transcript.baseName
            let formattedName = "000_\(baseName)"
            return recordingsURL.appendingPathComponent(voiceName).appendingPathComponent("\(formattedName).wav")
        }
        
        let baseName = transcript.baseName
        let formattedName = String(format: "%03d_%@", index + 1, baseName)
        return recordingsURL.appendingPathComponent(voiceName).appendingPathComponent("\(formattedName).wav")
    }
    
    func transcriptOutputURL(for transcript: Transcript, voiceName: String) -> URL {
        guard let index = transcriptIndex(for: transcript) else {
            let baseName = transcript.baseName
            let formattedName = "000_\(baseName)"
            return recordingsURL.appendingPathComponent(voiceName).appendingPathComponent("\(formattedName).txt")
        }
        
        let baseName = transcript.baseName
        let formattedName = String(format: "%03d_%@", index + 1, baseName)
        return recordingsURL.appendingPathComponent(voiceName).appendingPathComponent("\(formattedName).txt")
    }
    
    private func transcriptIndex(for transcript: Transcript) -> Int? {
        let files = try? FileManager.default.contentsOfDirectory(at: transcriptsURL, includingPropertiesForKeys: nil)
        let txtFiles = files?.filter { $0.pathExtension.lowercased() == "txt" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        return txtFiles?.firstIndex { $0.lastPathComponent == transcript.filename }
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

