import Foundation
import Combine
import AppKit

class HistoryManager: ObservableObject {
    @Published var transcriptions: [Transcription] = []
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "transcription_history"
    private let maxHistoryItems = 50 // Limit to last 50 transcriptions
    
    init() {
        loadHistory()
    }
    
    func addTranscription(_ transcription: Transcription) {
        // Add to beginning of array (most recent first)
        transcriptions.insert(transcription, at: 0)
        
        // Limit the number of stored transcriptions
        if transcriptions.count > maxHistoryItems {
            transcriptions = Array(transcriptions.prefix(maxHistoryItems))
        }
        
        saveHistory()
        print("HistoryManager: Added transcription: '\(transcription.text)'")
    }
    
    func removeTranscription(_ transcription: Transcription) {
        transcriptions.removeAll { $0.id == transcription.id }
        saveHistory()
        print("HistoryManager: Removed transcription with ID: \(transcription.id)")
    }
    
    func clearHistory() {
        transcriptions.removeAll()
        saveHistory()
        print("HistoryManager: Cleared all transcription history")
    }
    
    func copyToClipboard(_ transcription: Transcription) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcription.text, forType: .string)
        print("HistoryManager: Copied to clipboard: '\(transcription.text)'")
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(transcriptions)
            userDefaults.set(data, forKey: historyKey)
            print("HistoryManager: Saved \(transcriptions.count) transcriptions to UserDefaults")
        } catch {
            print("HistoryManager: Failed to save history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard let data = userDefaults.data(forKey: historyKey) else {
            print("HistoryManager: No existing history found")
            return
        }
        
        do {
            transcriptions = try JSONDecoder().decode([Transcription].self, from: data)
            print("HistoryManager: Loaded \(transcriptions.count) transcriptions from UserDefaults")
        } catch {
            print("HistoryManager: Failed to load history: \(error)")
            transcriptions = [] // Reset to empty array on decode error
        }
    }
    
    // Get transcriptions for a specific date
    func transcriptionsForDate(_ date: Date) -> [Transcription] {
        let calendar = Calendar.current
        return transcriptions.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }
    
    // Get recent transcriptions (last N items)
    func recentTranscriptions(count: Int = 10) -> [Transcription] {
        return Array(transcriptions.prefix(count))
    }
} 