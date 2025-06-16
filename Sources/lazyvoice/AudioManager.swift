import Foundation
import AVFoundation
import Combine
import AudioUnit

class AudioManager: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioBuffer: AVAudioPCMBuffer?
    private var recordingTimer: Timer?
    private var maxRecordingDuration: TimeInterval = 60.0
    
    private var recordedSamples: [Float] = []
    private var sampleRate: Double = 44100.0 // Track the actual sample rate
    
    // Callback for when recording completes
    var onRecordingComplete: (([Float], Double) -> Void)?
    
    init() {
        setupAudioSession()
    }
    
    deinit {
        // Clean up audio resources including callback
        cleanupForDeinit()
    }
    
    private func cleanup() {
        if isRecording {
            // This will handle tap removal, engine stop, and timer cleanup
            stopRecording()
        } else {
            // Not recording – do lightweight cleanup
            recordingTimer?.invalidate()
            recordingTimer = nil
            
            // Remove tap if one exists (defensive)
            audioEngine.inputNode.removeTap(onBus: 0)
            
            if audioEngine.isRunning {
                audioEngine.stop()
            }
        }
        
        print("AudioManager: Cleaned up resources")
    }
    
    private func cleanupForDeinit() {
        cleanup()
        
        // Only clear callback on deinit to prevent retain cycles
        onRecordingComplete = nil
    }
    
    private func setupAudioSession() {
        // On macOS, microphone permission is handled by the system automatically
        // when the app tries to access the microphone. The Info.plist entry
        // NSMicrophoneUsageDescription will trigger the permission prompt.
        print("AudioManager: Audio session setup completed")
    }
    
    private func resetAudioEngineForCurrentDevices() {
        // Reset the audio engine to pick up current device configuration
        // This is important when headphones are connected/disconnected
        print("AudioManager: Resetting audio engine for current device configuration")
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Create a completely new audio engine instance
        audioEngine = AVAudioEngine()
        print("AudioManager: Created new audio engine instance")
    }
    
    private func logAvailableInputDevices() {
        // Create a discovery session to find all available microphones
        var deviceTypes: [AVCaptureDevice.DeviceType] = []
        
        // Use different device types based on macOS version
        if #available(macOS 14.0, *) {
            deviceTypes = [.microphone, .external]
        } else {
            deviceTypes = [.builtInMicrophone, .externalUnknown]
        }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .audio,
            position: .unspecified
        )
        
        let availableDevices = discoverySession.devices
        print("AudioManager: Available input devices:")
        for device in availableDevices {
            print("  - \(device.localizedName) (\(device.deviceType.rawValue)) ID: \(device.uniqueID)")
        }
        
        // Also check what the system considers the default
        if let defaultDevice = AVCaptureDevice.default(for: .audio) {
            print("AudioManager: System default input device: \(defaultDevice.localizedName)")
        } else {
            print("AudioManager: No default input device found")
        }
        
        // Log AVAudioEngine's input node info after reset
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let outputFormat = inputNode.outputFormat(forBus: 0)
        print("AudioManager: AVAudioEngine input node - Input: \(inputFormat), Output: \(outputFormat)")
    }
    
    func startRecording() {
        guard !isRecording else { 
            print("AudioManager: Already recording, ignoring start request")
            return 
        }
        
        do {
            // Clean up any previous state
            cleanup()
            
            // Always reset audio engine to handle device changes (like headphones)
            resetAudioEngineForCurrentDevices()
            
            // Log available input devices for debugging
            logAvailableInputDevices()
            
            // Clear previous recording
            recordedSamples.removeAll()
            recordedSamples.reserveCapacity(1_000_000) // Pre-allocate for ~20 seconds at 48kHz
            
            // Configure audio engine
            inputNode = audioEngine.inputNode
            let recordingFormat = inputNode?.outputFormat(forBus: 0)
            
            // Get the actual sample rate
            if let format = recordingFormat {
                sampleRate = format.sampleRate
                print("AudioManager: Recording at \(sampleRate)Hz")
            }
            
            // Install tap to capture audio with weak reference
            inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                autoreleasepool {
                    self?.processAudioBuffer(buffer)
                }
            }
            
            // Start audio engine
            try audioEngine.start()
            
            DispatchQueue.main.async { [weak self] in
                self?.isRecording = true
            }
            
            // Set up maximum recording duration timer with weak reference
            recordingTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
                self?.stopRecording()
            }
            
            print("AudioManager: Recording started at \(sampleRate)Hz")
            
        } catch {
            print("AudioManager: Failed to start recording: \(error)")
            
            // Ensure we clean up on error
            DispatchQueue.main.async { [weak self] in
                self?.isRecording = false
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { 
            print("AudioManager: Not recording, ignoring stop request")
            return 
        }
        
        // Remove tap BEFORE stopping the engine to avoid potential crashes
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Stop audio engine safely
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Clean up timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Update state on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isRecording = false
            self.audioLevel = 0.0
        }
        
        let sampleCount = recordedSamples.count
        print("AudioManager: Recording stopped. Captured \(sampleCount) samples at \(sampleRate)Hz")
        
        // Call completion handler with recorded samples and sample rate
        // Use a local copy to avoid potential issues
        let samples = recordedSamples
        let rate = sampleRate
        
        print("AudioManager: About to call onRecordingComplete with \(samples.count) samples")
        print("AudioManager: onRecordingComplete callback is \(onRecordingComplete != nil ? "set" : "nil")")
        
        // Call on a background queue to prevent blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                print("AudioManager: self is nil in completion callback")
                return
            }
            guard let callback = self.onRecordingComplete else {
                print("AudioManager: onRecordingComplete callback is nil")
                return
            }
            print("AudioManager: Calling onRecordingComplete callback now")
            callback(samples, rate)
            print("AudioManager: onRecordingComplete callback completed")
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Safety checks
        guard isRecording else { return }
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        
        // Prevent excessive memory usage
        guard recordedSamples.count < 5_000_000 else { // ~1.5 minutes at 48kHz
            print("AudioManager: Recording too long, stopping")
            DispatchQueue.main.async { [weak self] in
                self?.stopRecording()
            }
            return
        }
        
        // Convert to Float array for whisper.cpp
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        recordedSamples.append(contentsOf: samples)
        
        // Calculate audio level for visual feedback
        let sum = samples.reduce(0) { $0 + abs($1) }
        let avgLevel = sum / Float(frameLength)
        
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = avgLevel
        }
    }
    
    func setMaxRecordingDuration(_ duration: TimeInterval) {
        maxRecordingDuration = max(1.0, min(duration, 300.0)) // 1 second to 5 minutes
        print("AudioManager: Max recording duration set to \(maxRecordingDuration) seconds")
    }
} 