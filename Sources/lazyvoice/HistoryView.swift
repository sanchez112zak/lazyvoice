import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyManager: HistoryManager
    @State private var searchText = ""
    @State private var selectedTranscription: Transcription?
    @Environment(\.dismiss) private var dismiss
    
    var filteredTranscriptions: [Transcription] {
        if searchText.isEmpty {
            return historyManager.transcriptions
        } else {
            return historyManager.transcriptions.filter { 
                $0.text.localizedCaseInsensitiveContains(searchText) 
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search transcriptions...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                
                // History list
                if filteredTranscriptions.isEmpty {
                    Spacer()
                    if historyManager.transcriptions.isEmpty {
                        VStack {
                            Image(systemName: "mic.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No Transcriptions Yet")
                                .font(.title2)
                                .fontWeight(.medium)
                                .padding(.top)
                            Text("Your transcription history will appear here")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No Results")
                                .font(.title2)
                                .fontWeight(.medium)
                                .padding(.top)
                            Text("Try adjusting your search")
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                } else {
                    List(filteredTranscriptions) { transcription in
                        TranscriptionRow(
                            transcription: transcription,
                            onCopy: { historyManager.copyToClipboard(transcription) },
                            onDelete: { historyManager.removeTranscription(transcription) }
                        )
                    }
                    .listStyle(PlainListStyle())
                }
                
                // Footer with stats
                if !historyManager.transcriptions.isEmpty {
                    HStack {
                        Text("\(historyManager.transcriptions.count) transcriptions")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Spacer()
                        Button("Clear All") {
                            showClearConfirmation()
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                    .padding()
                }
            }
            .navigationTitle("Transcription History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private func showClearConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Clear All Transcriptions?"
        alert.informativeText = "This action cannot be undone."
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            historyManager.clearHistory()
        }
    }
}

struct TranscriptionRow: View {
    let transcription: Transcription
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with time and actions
            HStack {
                Text(transcription.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isHovered {
                    HStack(spacing: 8) {
                        Button(action: onCopy) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.caption)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Copy to clipboard")
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Delete transcription")
                    }
                }
            }
            
            // Transcription text
            Text(transcription.text)
                .font(.body)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
            
            // Duration info if available
            if transcription.duration > 0 {
                Text("Duration: \(String(format: "%.1f", transcription.duration))s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            onCopy()
        }
    }
}

#Preview {
    let historyManager = HistoryManager()
    historyManager.transcriptions = [
        Transcription(text: "Hello, this is a test transcription."),
        Transcription(text: "Another longer transcription that might span multiple lines to test the UI layout."),
        Transcription(text: "Short one.")
    ]
    
    return HistoryView(historyManager: historyManager)
} 