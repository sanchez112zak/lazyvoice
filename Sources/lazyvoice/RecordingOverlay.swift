import SwiftUI

struct RecordingOverlay: View {
    @Binding var isVisible: Bool
    @Binding var isRecording: Bool
    @Binding var isTranscribing: Bool
    @State private var pulseScale: CGFloat = 1.0
    @ObservedObject private var audioManager: AudioManager
    
    init(isVisible: Binding<Bool>, isRecording: Binding<Bool>, isTranscribing: Binding<Bool>, audioManager: AudioManager) {
        self._isVisible = isVisible
        self._isRecording = isRecording
        self._isTranscribing = isTranscribing
        self._audioManager = ObservedObject(wrappedValue: audioManager)
    }
    
    var body: some View {
        if isVisible {
            VStack(spacing: 12) {
                // Recording indicator with pulsing animation
                HStack(spacing: 8) {
                    Circle()
                        .fill(isRecording ? Color.red : (isTranscribing ? Color.blue : Color.gray))
                        .frame(width: 12, height: 12)
                        .scaleEffect(pulseScale)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseScale)
                    
                    Text(currentStatusText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(statusColor)
                }
                
                // Recording indicator (simplified for now)
                if isRecording {
                    Text("🔴 REC")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                }
                
                // Cancel instruction
                Text("Press ESC to cancel")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private var currentStatusText: String {
        if isRecording {
            return "Recording..."
        } else if isTranscribing {
            return "Transcribing..."
        } else {
            return "Ready"
        }
    }
    
    private var statusColor: Color {
        if isRecording {
            return .red
        } else if isTranscribing {
            return .blue
        } else {
            return .primary
        }
    }
    
    // Note: Timer and animation lifecycle is now handled by RecordingOverlayController
}

// MARK: - RecordingOverlayController (Fixed Memory Management)
class RecordingOverlayController {
    private var window: NSWindow?
    private var isVisible = false
    private let audioManager: AudioManager
    
    init(audioManager: AudioManager) {
        self.audioManager = audioManager
    }
    
    deinit {
        // On final tear-down really close and release the window.
        if let window = window {
            window.orderOut(nil)
            window.close()
        }
    }
    
    private func cleanup() {
        if let window = window {
            // Just hide the window; keep it alive until deinit to avoid sudden
            // deallocation while Combine publishers might still deliver values.
            window.orderOut(nil)
        }
        isVisible = false
    }
    
    func showOverlay() {
        // Ensure we're on main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showOverlay()
            }
            return
        }
        
        // Prevent multiple overlays
        guard !isVisible else { 
            print("Overlay already visible")
            return 
        }
        
        // Clean up any existing window first
        cleanup()
        
        // Create overlay view that reacts to live audio level
        let overlayView = SimpleRecordingOverlay(audioManager: audioManager)
        
        // Create window with proper cleanup
        let windowRect = NSRect(x: 0, y: 0, width: 200, height: 80)
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        guard let window = window else {
            print("Failed to create overlay window")
            return
        }
        
        // Configure window 
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Position in bottom-center
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.minX + (screenFrame.width - windowFrame.width) / 2
            let y = screenFrame.minY + 20
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Set content and show
        window.contentView = NSHostingView(rootView: overlayView)
        window.makeKeyAndOrderFront(nil)
        
        isVisible = true
        print("Simple overlay shown")
    }
    
    func hideOverlay() {
        // Ensure we're on main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.hideOverlay()
            }
            return
        }
        
        // Prevent multiple hide calls
        guard isVisible else { 
            print("Overlay already hidden")
            return 
        }
        
        cleanup()
        print("Simple overlay hidden")
    }
}

// MARK: - Simple Recording Overlay View (Fixed)
struct SimpleRecordingOverlay: View {
    @State private var pulseScale: CGFloat = 1.0
    @ObservedObject private var audioManager: AudioManager
    
    init(audioManager: AudioManager) {
        self._audioManager = ObservedObject(wrappedValue: audioManager)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Pulsing mic indicator and status text
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseScale)
                Text("Recording…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }

            // Waveform that reacts to live audio
            WaveformView(level: audioManager.audioLevel)
                .frame(height: 36)
                .frame(maxWidth: 140)

            // Instruction
            Text("Press ESC to cancel")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
        )
        .onAppear {
            // Kick off pulsing animation
            DispatchQueue.main.async {
                pulseScale = 1.3
            }
        }
        .onDisappear {
            DispatchQueue.main.async {
                pulseScale = 1.0
            }
        }
    }
}

 