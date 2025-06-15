import Foundation
import Combine
import WhisperWrapper

enum WhisperError: Error {
    case couldNotInitializeContext
    case modelNotFound
    case transcriptionFailed
    case invalidInput
}

// Meet Whisper C++ constraint: Don't access from more than one thread at a time.
actor WhisperContext {
    private var context: OpaquePointer?
    
    init(context: OpaquePointer) {
        self.context = context
    }
    
    deinit {
        if let context = context {
            whisper_wrapper_free(context)
        }
    }
    
    func fullTranscribe(samples: [Float], sampleRate: Double = 16000.0) -> String {
        guard let context = context else {
            print("WhisperContext: No context available")
            return ""
        }
        
        // Resample audio to 16kHz if needed
        let resampledSamples = AudioResampler.resampleToWhisperFormat(samples: samples, fromSampleRate: sampleRate)
        
        // Ensure we have enough samples (minimum 1 second)
        guard resampledSamples.count >= 16000 else {
            print("WhisperContext: Not enough audio samples (\(resampledSamples.count) < 16000)")
            return ""
        }
        
        // Leave 2 processors free for system responsiveness
        let maxThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        print("WhisperContext: Using \(maxThreads) threads for transcription")
        
        // Wrap the C function call in an autorelease pool to prevent memory issues
        return autoreleasepool {
            // Prepare result buffer
            let resultBufferSize = 4096
            let resultBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: resultBufferSize)
            defer { resultBuffer.deallocate() }
            
            // Initialize the buffer to prevent garbage data
            resultBuffer.initialize(repeating: 0, count: resultBufferSize)
            
            // Call whisper C wrapper directly in the actor context
            let result = resampledSamples.withUnsafeBufferPointer { bufferPointer in
                return whisper_wrapper_full_transcribe(
                    context,
                    bufferPointer.baseAddress!,
                    Int32(resampledSamples.count),
                    resultBuffer,
                    Int32(resultBufferSize)
                )
            }
            
            if result == 0 {
                let transcription = String(cString: resultBuffer)
                print("WhisperContext: Transcription successful: '\(transcription)'")
                return transcription
            } else {
                print("WhisperContext: Transcription failed with code: \(result)")
                return ""
            }
        }
    }
    
    static func createContext(path: String) throws -> WhisperContext {
        guard FileManager.default.fileExists(atPath: path) else {
            print("WhisperContext: Model file not found at path: \(path)")
            throw WhisperError.modelNotFound
        }
        
        let context = whisper_wrapper_init_from_file(path)
        guard context != nil else {
            print("WhisperContext: Failed to initialize whisper context from file: \(path)")
            throw WhisperError.couldNotInitializeContext
        }
        
        print("WhisperContext: Successfully initialized context from: \(path)")
        return WhisperContext(context: context!)
    }
}

class WhisperManager: ObservableObject {
    @Published var isTranscribing = false
    @Published var lastTranscription = ""
    
    private var context: WhisperContext?
    private var currentModelName: String = ""
    private var cancellables = Set<AnyCancellable>()
    
    // Callback for when transcription completes
    var onTranscriptionComplete: ((String) -> Void)?
    
    init() {
        // Start monitoring preference changes
        setupPreferenceMonitoring()
        // Initialize with current preference
        reloadModelFromPreferences()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    private func setupPreferenceMonitoring() {
        // Monitor changes to whisperModel preference
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.reloadModelFromPreferences()
            }
            .store(in: &cancellables)
    }
    
    private func reloadModelFromPreferences() {
        let selectedModel = UserDefaults.standard.string(forKey: "whisperModel") ?? "tiny"
        let modelFileName = getModelFileName(for: selectedModel)
        
        // Only reload if model has changed
        guard modelFileName != currentModelName else {
            print("WhisperManager: Model unchanged (\(selectedModel)), skipping reload")
            return
        }
        
        print("WhisperManager: Reloading model from '\(currentModelName)' to '\(selectedModel)' (\(modelFileName))")
        currentModelName = modelFileName
        initializeWhisper(modelPath: modelFileName)
    }
    
    private func getModelFileName(for modelType: String) -> String {
        switch modelType {
        case "base":
            return "ggml-base.bin"
        case "small":
            return "ggml-small.bin"
        default:
            return "ggml-tiny.bin"
        }
    }

    private func initializeWhisper(modelPath: String) {
        do {
            var fullPath: String? = nil
            
            // Try multiple locations for the model file
            let executablePath = Bundle.main.executablePath ?? ""
            let executableDir = URL(fileURLWithPath: executablePath).deletingLastPathComponent().path
            
            let searchPaths = [
                // Bundle resource
                Bundle.main.path(forResource: modelPath.replacingOccurrences(of: ".bin", with: ""), ofType: "bin"),
                // Bundle resource with full name
                Bundle.main.path(forResource: modelPath, ofType: nil),
                // Bundle.main.url(forResource:) alternative
                Bundle.main.url(forResource: modelPath.replacingOccurrences(of: ".bin", with: ""), withExtension: "bin")?.path,
                Bundle.main.url(forResource: modelPath, withExtension: nil)?.path,
                // Current directory (for swift run)
                FileManager.default.currentDirectoryPath + "/" + modelPath,
                // Sources directory (for development)
                FileManager.default.currentDirectoryPath + "/Sources/lazyvoice/" + modelPath,
                // Executable directory (for app bundle)
                executableDir + "/" + modelPath,
                // Executable parent directory
                URL(fileURLWithPath: executableDir).deletingLastPathComponent().path + "/" + modelPath,
                // Built bundle directory
                FileManager.default.currentDirectoryPath + "/.build/arm64-apple-macosx/debug/lazyvoice_lazyvoice.bundle/" + modelPath,
                // Resources directory in bundle
                Bundle.main.resourcePath.map { $0 + "/" + modelPath },
                // Direct bundle Contents/Resources path
                executableDir + "/lazyvoice_lazyvoice.bundle/Contents/Resources/" + modelPath,
                // Bundle at executable directory level
                URL(fileURLWithPath: executableDir).appendingPathComponent("lazyvoice_lazyvoice.bundle").appendingPathComponent("Contents").appendingPathComponent("Resources").appendingPathComponent(modelPath).path
            ]
            
            for path in searchPaths {
                if let path = path, FileManager.default.fileExists(atPath: path) {
                    fullPath = path
                    break
                }
            }
            
            guard let resolvedModelPath = fullPath else {
                print("WhisperManager: Model file '\(modelPath)' not found in any search location")
                print("WhisperManager: Searched paths:")
                for path in searchPaths {
                    print("  - \(path ?? "nil")")
                }
                
                // Fallback to tiny model if requested model not found
                if modelPath != "ggml-tiny.bin" {
                    print("WhisperManager: Falling back to tiny model")
                    currentModelName = "ggml-tiny.bin"
                    initializeWhisper(modelPath: "ggml-tiny.bin")
                    return
                }
                
                throw WhisperError.modelNotFound
            }
            
            print("WhisperManager: Found model at: \(resolvedModelPath)")
            context = try WhisperContext.createContext(path: resolvedModelPath)
            print("WhisperManager: Whisper context initialized successfully with model: \(modelPath)")
        } catch {
            print("WhisperManager: Failed to initialize Whisper context: \(error)")
            context = nil
        }
    }
    
    func transcribe(samples: [Float], sampleRate: Double = 44100.0) {
        guard context != nil else {
            print("WhisperManager: Whisper context not initialized - returning mock transcription")
            // Return a mock transcription to prevent crashes
            DispatchQueue.main.async { [weak self] in
                self?.onTranscriptionComplete?("Transcription failed: Model not loaded")
            }
            return
        }
        
        guard !isTranscribing else {
            print("WhisperManager: Already transcribing, ignoring request")
            return
        }
        
        guard !samples.isEmpty else {
            print("WhisperManager: No audio samples provided")
            DispatchQueue.main.async { [weak self] in
                self?.onTranscriptionComplete?("No audio detected")
            }
            return
        }
        
        // Update state on main thread
        DispatchQueue.main.async { [weak self] in
            self?.isTranscribing = true
        }
        
        // Perform transcription in background task with proper isolation
        Task { [weak self] in
            guard let self = self, let context = self.context else { return }
            
            // Call the actor method and await result
            let transcription = await context.fullTranscribe(samples: samples, sampleRate: sampleRate)
            
            // Update state on main thread
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.isTranscribing = false
                self.lastTranscription = transcription
                print("WhisperManager: Transcription completed: '\(transcription)'")
                
                // Call completion handler
                self.onTranscriptionComplete?(transcription)
            }
        }
    }
    
    // Legacy method for compatibility
    func updateModelPath(_ newPath: String) {
        // This method is now handled automatically via preference monitoring
        print("WhisperManager: updateModelPath called with \(newPath) - this is now handled automatically")
    }
} 