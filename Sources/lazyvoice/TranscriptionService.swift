import Foundation
import AppKit
import Combine
import UserNotifications
import ApplicationServices
import AVFoundation

class TranscriptionService: ObservableObject {
    @Published var isActive = false
    @Published var currentStatus = "Ready"
    
    let audioManager = AudioManager()
    private let whisperManager = WhisperManager()
    private var cancellables = Set<AnyCancellable>()
    private let errorManager = ErrorManager.shared
    
    // History management
    let historyManager = HistoryManager()
    
    // Recording tracking for history
    private var recordingStartTime: Date?
    
    init() {
        setupBindings()
        // Request notification permissions after a delay to ensure app is fully launched
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.requestNotificationPermissions()
            self.checkAccessibilityPermissions()
        }
    }
    
    deinit {
        // Clean up to prevent crashes
        audioManager.onRecordingComplete = nil
        whisperManager.onTranscriptionComplete = nil
        cancellables.removeAll()
    }
    
    private func requestNotificationPermissions() {
        // Check if we can access the notification center
        guard Bundle.main.bundleIdentifier != nil else {
            print("Running without proper bundle, skipping notification permissions")
            return
        }
        
        do {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error = error {
                    print("Error requesting notification permissions: \(error)")
                } else if granted {
                    print("Notification permissions granted")
                } else {
                    print("Notification permissions denied")
                }
            }
        } catch {
            print("Error accessing notification center: \(error)")
        }
    }
    
    private func checkAccessibilityPermissions() {
        let trusted = AXIsProcessTrusted()
        if trusted {
            print("Accessibility permissions: ✅ GRANTED - Auto-paste will work")
        } else {
            print("Accessibility permissions: ❌ DENIED - Auto-paste won't work")
            print("To enable auto-paste:")
            print("1. Open System Settings → Privacy & Security → Accessibility")
            print("2. Add and enable this app or Xcode")
            print("3. Restart the app")
        }
    }
    
    private func setupBindings() {
        // Listen for recording completion with weak references
        audioManager.onRecordingComplete = { [weak self] samples, sampleRate in
            print("TranscriptionService: onRecordingComplete callback triggered with \(samples.count) samples")
            guard let self = self else { 
                print("TranscriptionService: self is nil in onRecordingComplete callback")
                return 
            }
            self.handleRecordingComplete(samples: samples, sampleRate: sampleRate)
        }
        
        // Listen for transcription completion with weak references
        whisperManager.onTranscriptionComplete = { [weak self] transcription in
            print("TranscriptionService: onTranscriptionComplete callback triggered")
            guard let self = self else { 
                print("TranscriptionService: self is nil in onTranscriptionComplete callback")
                return 
            }
            self.handleTranscriptionComplete(transcription: transcription)
        }
        
        print("TranscriptionService: Callbacks set up successfully")
        print("TranscriptionService: audioManager.onRecordingComplete is \(audioManager.onRecordingComplete != nil ? "set" : "nil")")
    }
    
    func startRecording() {
        guard !isActive else { 
            print("TranscriptionService: Already active, ignoring start request")
            return 
        }
        
        // Check microphone permission before starting
        guard errorManager.checkMicrophonePermission() else {
            print("TranscriptionService: Microphone permission denied")
            return
        }
        
        isActive = true
        currentStatus = "Recording..."
        recordingStartTime = Date() // Track when recording started
        audioManager.startRecording()
        print("Transcription service: Recording started")
    }
    
    func stopRecording() {
        guard isActive else { 
            print("TranscriptionService: Not active, ignoring stop request")
            return 
        }
        
        currentStatus = "Processing..."
        audioManager.stopRecording()
        print("Transcription service: Recording stopped")
    }
    
    private func handleRecordingComplete(samples: [Float], sampleRate: Double) {
        print("Transcription service: Processing \(samples.count) audio samples at \(sampleRate)Hz")
        
        // Validate samples to prevent potential issues
        guard !samples.isEmpty else {
            print("TranscriptionService: Empty samples received")
            errorManager.handleError(.audioRecordingFailed("No audio detected"))
            resetToReady()
            return
        }
        
        // Check for reasonable sample count to prevent memory issues
        guard samples.count < 10_000_000 else { // 10M samples max (~3 minutes at 48kHz)
            print("TranscriptionService: Sample count too large: \(samples.count)")
            errorManager.handleError(.audioRecordingFailed("Recording too long (max 3 minutes)"))
            resetToReady()
            return
        }
        
        // Check for minimum viable audio
        let audioLevel = samples.map { abs($0) }.max() ?? 0.0
        guard audioLevel > 0.0001 else { // Very quiet threshold
            print("TranscriptionService: Audio too quiet: \(audioLevel)")
            errorManager.handleError(.audioRecordingFailed("Audio too quiet - try speaking louder"))
            resetToReady()
            return
        }
        
        currentStatus = "Transcribing..."
        
        // Start transcription with sample rate information
        whisperManager.transcribe(samples: samples, sampleRate: sampleRate)
    }
    
    private func resetToReady() {
        DispatchQueue.main.async { [weak self] in
            self?.currentStatus = "Ready"
            self?.isActive = false
            self?.recordingStartTime = nil
        }
    }
    
    private func handleTranscriptionComplete(transcription: String) {
        print("Transcription service: Transcription completed - \(transcription)")
        
        // Calculate recording duration
        let duration = recordingStartTime?.timeIntervalSinceNow.magnitude ?? 0
        
        // Create transcription record and add to history
        let transcriptionRecord = Transcription(
            text: transcription,
            duration: duration,
            sampleRate: 16000 // whisper.cpp always uses 16kHz
        )
        historyManager.addTranscription(transcriptionRecord)
        
        // Ensure we're on main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Always do both: copy to clipboard AND auto-paste
            self.copyToClipboardAndAutoPaste(transcription)
            
            self.currentStatus = "Ready"
            self.isActive = false
            self.recordingStartTime = nil // Reset recording start time
        }
    }
    
    private func copyToClipboardAndAutoPaste(_ text: String) {
        // First, always copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        print("Transcription copied to clipboard: \(text)")
        
        // Then attempt auto-paste if accessibility permissions are available
        let trusted = AXIsProcessTrusted()
        if trusted {
            // Simulate paste (Cmd+V) after a short delay to ensure clipboard is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                autoreleasepool {
                    // Create Cmd+V key press
                    guard let cmdVDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
                          let cmdVUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else {
                        print("Auto-paste: Failed to create key events")
                        return
                    }
                    
                    // Set Command modifier flag
                    cmdVDown.flags = .maskCommand
                    cmdVUp.flags = .maskCommand
                    
                    // Post the events
                    cmdVDown.post(tap: .cghidEventTap)
                    cmdVUp.post(tap: .cghidEventTap)
                    
                    print("Auto-paste executed for text: '\(text)'")
                    
                    // Show notification for successful auto-paste
                    self.showNotification(title: "Transcription Complete", message: "Text copied to clipboard and auto-pasted")
                }
            }
        } else {
            print("Auto-paste: No accessibility permissions. Text copied to clipboard only.")
            // Show notification for clipboard-only
            showNotification(title: "Transcription Complete", message: "Text copied to clipboard (enable Accessibility permission for auto-paste)")
        }
    }
    
    private func showNotification(title: String, message: String) {
        // Check if we can access the notification center
        guard Bundle.main.bundleIdentifier != nil else {
            print("Notification: \(title) - \(message)")
            return
        }
        
        do {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            
            let center = UNUserNotificationCenter.current()
            center.add(request) { error in
                if let error = error {
                    print("Error showing notification: \(error)")
                }
            }
        } catch {
            print("Error accessing notification center: \(error)")
            print("Notification: \(title) - \(message)")
        }
    }
    
    func setMaxRecordingDuration(_ duration: TimeInterval) {
        audioManager.setMaxRecordingDuration(duration)
    }
} 