import Foundation

struct Transcription: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let duration: TimeInterval
    let sampleRate: Double
    
    init(text: String, duration: TimeInterval = 0, sampleRate: Double = 16000) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.duration = duration
        self.sampleRate = sampleRate
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }
} 