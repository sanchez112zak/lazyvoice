import SwiftUI
import AppKit
import QuartzCore

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
        
        // Create window with proper configuration for pixel-perfect rendering
        let windowRect = NSRect(x: 0, y: 0, width: 180, height: 80)
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
        
        // Configure window for pixel-perfect Apple-style overlay with full transparency
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false  // Let SwiftUI handle shadows
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.animationBehavior = .none
        
        // Position in bottom-center
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.minX + (screenFrame.width - windowFrame.width) / 2
            let y = screenFrame.minY + 100
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Set content with proper hosting configuration for full transparency
        let hostingView = NSHostingView(rootView: overlayView)
        
        // Ensure complete transparency at all levels
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        hostingView.wantsLayer = true
        
        // Make sure the hosting view itself is transparent
        hostingView.layer?.masksToBounds = false
        
        window.contentView = hostingView
        
        // Final transparency check - ensure window content view background is clear
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        // CRITICAL: Shape the window to match the rounded rectangle to eliminate dark corners
        DispatchQueue.main.async {
            let rect = NSRect(x: 0, y: 0, width: 180, height: 80)
            let path = NSBezierPath(roundedRect: rect, xRadius: 20, yRadius: 20)
            
            let shapeLayer = CAShapeLayer()
            if #available(macOS 14.0, *) {
                shapeLayer.path = path.cgPath
            } else {
                // Fallback for older macOS versions
                let cgPath = CGMutablePath()
                cgPath.addRoundedRect(in: CGRect(x: 0, y: 0, width: 180, height: 80), 
                                     cornerWidth: 20, cornerHeight: 20)
                shapeLayer.path = cgPath
            }
            
            window.contentView?.layer?.mask = shapeLayer
        }
        
        window.makeKeyAndOrderFront(nil)
        
        isVisible = true
        print("Optimized overlay shown")
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
        print("Optimized overlay hidden")
    }
}

// MARK: - Simple Recording Overlay View (Fixed)
struct SimpleRecordingOverlay: View {
    @ObservedObject private var audioManager: AudioManager
    
    init(audioManager: AudioManager) {
        self._audioManager = ObservedObject(wrappedValue: audioManager)
    }
    
    var body: some View {
        // Just the beautiful waveform - ultra minimal with perfect transparency
        WaveformView(level: audioManager.audioLevel)
            .frame(height: 50)
            .frame(width: 180, height: 80)
            .background {
                // Perfect Apple-style rounded square
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.black)
                    .overlay {
                        // Subtle inner highlight for depth
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.08),
                                        .clear,
                                        .white.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        // Clean border definition
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                    }
            }
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
            .compositingGroup() // Ensure proper compositing for transparency
            .clipped() // Clip to bounds to prevent any overflow
    }
}

 