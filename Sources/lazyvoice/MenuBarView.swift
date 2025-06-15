import SwiftUI

struct MenuBarView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var whisperManager = WhisperManager()
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "mic")
                Text("lazyvoice")
                    .font(.headline)
            }
            
            if audioManager.isRecording {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.red)
                    Text("Recording...")
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
            }
            
            if whisperManager.isTranscribing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Transcribing...")
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }
} 