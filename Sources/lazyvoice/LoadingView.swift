import SwiftUI
import AppKit
import Combine

struct LoadingView: View {
    @State private var animationProgress: CGFloat = 0.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var fadeInOpacity: CGFloat = 0.0
    @Binding var loadingText: String
    @Binding var progress: Double
    
    private let gradientColors = [
        Color(red: 0.2, green: 0.6, blue: 1.0),
        Color(red: 0.4, green: 0.3, blue: 0.9),
        Color(red: 0.6, green: 0.2, blue: 0.8)
    ]
    
    var body: some View {
        ZStack {
            // Background with subtle gradient
            LinearGradient(
                colors: [
                    Color.black.opacity(0.95),
                    Color.black.opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // App logo/icon area with pulsing animation
                VStack(spacing: 16) {
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 100, height: 100)
                            .scaleEffect(pulseScale)
                            .opacity(0.6)
                        
                        // Inner icon
                        Image(systemName: "mic.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .scaleEffect(0.9 + pulseScale * 0.1)
                    }
                    
                    // App name
                    Text("lazyvoice")
                        .font(.system(size: 28, weight: .light, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(fadeInOpacity)
                }
                
                // Loading indicator
                VStack(spacing: 20) {
                    // Animated progress bar
                    VStack(spacing: 12) {
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 200, height: 4)
                            
                            // Progress fill
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: gradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 200 * progress, height: 4)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                        
                        // Progress percentage
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Loading text with typewriter effect
                    Text(loadingText)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(fadeInOpacity)
                        .animation(.easeInOut(duration: 0.5), value: loadingText)
                }
                
                Spacer()
                
                // Subtle rotating loading indicators at bottom
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 6, height: 6)
                            .scaleEffect(1.0 + 0.3 * sin(animationProgress + Double(index) * 0.5))
                            .animation(
                                .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: animationProgress
                            )
                    }
                }
                .opacity(fadeInOpacity * 0.6)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            // Start animations
            withAnimation(.easeInOut(duration: 0.8)) {
                fadeInOpacity = 1.0
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
            
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                animationProgress = 2 * .pi
            }
        }
    }
}

// MARK: - Loading Window Controller
class LoadingWindowController: NSObject, ObservableObject, NSWindowDelegate {
    private var window: NSWindow?
    private var loadingView: LoadingView?
    private var loadingText = "Initializing lazyvoice..."
    private var progress: Double = 0.0
    
    private let loadingSteps = [
        "Initializing lazyvoice...",
        "Loading audio subsystem...",
        "Preparing ML models...",
        "Setting up permissions...",
        "Finalizing setup..."
    ]
    
    func showLoadingScreen() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showLoadingScreen()
            }
            return
        }
        
        // Create loading view with @State wrappers
        let loadingView = LoadingViewContainer(controller: self)
        
        // Create a moderately sized centered window
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 300
        
        // Get main screen to center the window
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        let windowRect = NSRect(
            x: (screenFrame.width - windowWidth) / 2,
            y: (screenFrame.height - windowHeight) / 2,
            width: windowWidth,
            height: windowHeight
        )
        
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        guard let window = window else { return }
        
        // Configure window
        window.title = "Loading lazyvoice..."
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.isMovable = true
        window.canHide = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces]
        
        // Set content view
        window.contentView = NSHostingView(rootView: loadingView)
        
        // Set delegate to prevent app termination
        window.delegate = self
        
        // Center and show window
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Start the loading sequence
        startLoadingSequence()
    }
    
    func hideLoadingScreen() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { 
                print("⚠️ No loading window to hide")
                return 
            }
            
            print("🔄 Hiding loading screen...")
            
            // Fade out animation
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = 0.0
            } completionHandler: { [weak self] in
                window.orderOut(nil)
                window.close()
                self?.window = nil
                print("✅ Loading screen hidden and closed")
            }
        }
    }
    
    private func startLoadingSequence() {
        // Simulate loading steps with realistic timing
        let stepDuration: TimeInterval = 0.8
        let totalSteps = loadingSteps.count
        
        for (index, step) in loadingSteps.enumerated() {
            let delay = TimeInterval(index) * stepDuration
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.loadingText = step
                self?.progress = Double(index + 1) / Double(totalSteps)
            }
        }
    }
    
    func updateProgress(_ newProgress: Double, text: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.progress = newProgress
            if let text = text {
                self?.loadingText = text
            }
        }
    }
    
    // Getters for the container view
    func getCurrentText() -> String {
        return loadingText
    }
    
    func getCurrentProgress() -> Double {
        return progress
    }
    
    // MARK: - NSWindowDelegate
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow the loading window to close normally
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        print("🪟 Loading window will close - this should NOT terminate the app")
    }
}

// MARK: - Container View for State Management
struct LoadingViewContainer: View {
    weak var controller: LoadingWindowController?
    @State private var loadingText = "Initializing lazyvoice..."
    @State private var progress: Double = 0.0
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        LoadingView(loadingText: $loadingText, progress: $progress)
            .onReceive(timer) { _ in
                // Update from controller
                if let controller = controller {
                    loadingText = controller.getCurrentText()
                    progress = controller.getCurrentProgress()
                }
            }
            .onAppear {
                if let controller = controller {
                    loadingText = controller.getCurrentText()
                    progress = controller.getCurrentProgress()
                }
            }
    }
}

#Preview {
    LoadingView(
        loadingText: .constant("Loading ML models..."),
        progress: .constant(0.6)
    )
    .frame(width: 400, height: 300)
} 