import Foundation
import SwiftUI
import UserNotifications
import AVFoundation
import ApplicationServices

// MARK: - Error Types
enum TranscriptionError: LocalizedError {
    case microphonePermissionDenied
    case accessibilityPermissionDenied
    case audioRecordingFailed(String)
    case whisperModelLoadFailed(String)
    case transcriptionFailed(String)
    case hotkeyRegistrationFailed(String)
    case storageError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access denied. Please grant permission in System Settings."
        case .accessibilityPermissionDenied:
            return "Accessibility permission required for auto-paste. Please enable in System Settings."
        case .audioRecordingFailed(let reason):
            return "Audio recording failed: \(reason)"
        case .whisperModelLoadFailed(let reason):
            return "Failed to load transcription model: \(reason)"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .hotkeyRegistrationFailed(let reason):
            return "Hotkey registration failed: \(reason)"
        case .storageError(let reason):
            return "Storage error: \(reason)"
        case .unknownError(let reason):
            return "Unknown error: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Open System Settings → Privacy & Security → Microphone and enable access for this app."
        case .accessibilityPermissionDenied:
            return "Open System Settings → Privacy & Security → Accessibility and enable access for this app."
        case .audioRecordingFailed:
            return "Check your microphone connection and try again."
        case .whisperModelLoadFailed:
            return "Restart the app or reinstall to fix missing model files."
        case .transcriptionFailed:
            return "Try recording again with clearer audio."
        case .hotkeyRegistrationFailed:
            return "Try changing the hotkey combination in Preferences."
        case .storageError:
            return "Check available disk space and app permissions."
        case .unknownError:
            return "Restart the app and try again."
        }
    }
}

// MARK: - Error Manager
class ErrorManager: ObservableObject {
    @Published var currentError: TranscriptionError?
    @Published var showingError = false
    
    static let shared = ErrorManager()
    
    private init() {}
    
    // MARK: - Error Handling Methods
    func handleError(_ error: TranscriptionError) {
        DispatchQueue.main.async {
            print("❌ ERROR: \(error.localizedDescription)")
            if let recovery = error.recoverySuggestion {
                print("💡 RECOVERY: \(recovery)")
            }
            
            self.currentError = error
            self.showingError = true
            
            // Also show as notification for background errors
            self.showErrorNotification(error)
        }
    }
    
    func handleError(_ error: Error) {
        let transcriptionError = TranscriptionError.unknownError(error.localizedDescription)
        handleError(transcriptionError)
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.showingError = false
        }
    }
    
    // MARK: - Specific Error Helpers
    func checkMicrophonePermission() -> Bool {
        // On macOS, we use AVCaptureDevice for microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            handleError(.microphonePermissionDenied)
            return false
        case .notDetermined:
            // Request permission asynchronously
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if !granted {
                    self.handleError(.microphonePermissionDenied)
                }
            }
            return false
        @unknown default:
            return false
        }
    }
    
    func checkAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            handleError(.accessibilityPermissionDenied)
        }
        return trusted
    }
    
    // MARK: - Notification Helper
    private func showErrorNotification(_ error: TranscriptionError) {
        // Check if we can access the notification center
        guard Bundle.main.bundleIdentifier != nil else {
            print("Error notification: \(error.localizedDescription)")
            return
        }
        
        do {
            let content = UNMutableNotificationContent()
            content.title = "lazyvoice Error"
            content.body = error.localizedDescription
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "error-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            
            let center = UNUserNotificationCenter.current()
            center.add(request) { error in
                if let error = error {
                    print("Failed to show error notification: \(error)")
                }
            }
        } catch {
            print("Error accessing notification center: \(error)")
            print("Error notification: \(error.localizedDescription)")
        }
    }
}

// MARK: - SwiftUI Error Alert View Modifier
struct ErrorAlert: ViewModifier {
    @StateObject private var errorManager = ErrorManager.shared
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorManager.showingError) {
                Button("OK") {
                    errorManager.clearError()
                }
                if let error = errorManager.currentError,
                   error.recoverySuggestion != nil {
                    Button("Open Settings") {
                        openSystemSettings(for: error)
                        errorManager.clearError()
                    }
                }
            } message: {
                if let error = errorManager.currentError {
                    VStack(alignment: .leading) {
                        Text(error.localizedDescription)
                        if let recovery = error.recoverySuggestion {
                            Text(recovery)
                                .font(.caption)
                        }
                    }
                }
            }
    }
    
    private func openSystemSettings(for error: TranscriptionError) {
        let url: URL?
        
        switch error {
        case .microphonePermissionDenied:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .accessibilityPermissionDenied:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        default:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security")
        }
        
        if let url = url {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - View Extension
extension View {
    func errorAlert() -> some View {
        modifier(ErrorAlert())
    }
} 