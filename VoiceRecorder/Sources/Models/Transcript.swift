import Foundation

struct Transcript: Identifiable, Equatable {
    let id: UUID
    let filename: String
    let text: String
    var isRecorded: Bool
    
    var baseName: String {
        (filename as NSString).deletingPathExtension
    }
    
    init(filename: String, text: String, isRecorded: Bool = false) {
        self.id = UUID()
        self.filename = filename
        self.text = text
        self.isRecorded = isRecorded
    }
}

