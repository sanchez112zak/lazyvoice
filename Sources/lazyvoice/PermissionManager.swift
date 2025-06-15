import Foundation
import SwiftUI
import AVFoundation
import ApplicationServices
import UserNotifications

// MARK: - Permission Status
enum PermissionStatus {
    case granted
    case denied
    case notDetermined
    case restricted
}

// MARK: - Permission Types
enum PermissionType: String, CaseIterable {
    case microphone = "Microphone"
    case accessibility = "Accessibility" 
    case notifications = "Notifications"
    
    var icon: String {
        switch self {
        case .microphone: return "mic"
        case .accessibility: return "accessibility"
        case .notifications: return "bell"
        }
    }
    
    var description: String {
        switch self {
        case .microphone: return "Required for recording audio"
        case .accessibility: return "Required for auto-paste functionality"
        case .notifications: return "Optional for transcription alerts"
        }
    }
}

// MARK: - Permission Manager
class PermissionManager: ObservableObject {
    @Published var microphoneStatus: PermissionStatus = .notDetermined
    @Published var accessibilityStatus: PermissionStatus = .notDetermined
    @Published var notificationStatus: PermissionStatus = .notDetermined
    @Published var showingPermissionOnboarding = false
    
    static let shared = PermissionManager()
    
    private init() {
        checkAllPermissions()
    }
    
    // MARK: - Permission Checking
    func checkAllPermissions() {
        checkMicrophonePermission()
        checkAccessibilityPermission() 
        checkNotificationPermission()
    }
    
    func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneStatus = .granted
        case .denied, .restricted:
            microphoneStatus = .denied
        case .notDetermined:
            microphoneStatus = .notDetermined
        @unknown default:
            microphoneStatus = .notDetermined
        }
    }
    
    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        accessibilityStatus = trusted ? .granted : .denied
    }
    
    func checkNotificationPermission() {
        // Check if we have a valid bundle identifier before accessing notification center
        guard Bundle.main.bundleIdentifier != nil else {
            print("PermissionManager: Running without proper bundle, skipping notification permission check")
            notificationStatus = .notDetermined
            return
        }
        
        // Safely access notification center with error handling
        do {
            let center = UNUserNotificationCenter.current()
            center.getNotificationSettings { settings in
                DispatchQueue.main.async {
                    switch settings.authorizationStatus {
                    case .authorized, .provisional:
                        self.notificationStatus = .granted
                    case .denied:
                        self.notificationStatus = .denied
                    case .notDetermined:
                        self.notificationStatus = .notDetermined
                    case .ephemeral:
                        self.notificationStatus = .granted
                    @unknown default:
                        self.notificationStatus = .notDetermined
                    }
                }
            }
        } catch {
            print("PermissionManager: Error accessing notification center: \(error)")
            notificationStatus = .notDetermined
        }
    }
    
    // MARK: - Permission Requesting
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.microphoneStatus = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        // Check if we have a valid bundle identifier before accessing notification center
        guard Bundle.main.bundleIdentifier != nil else {
            print("PermissionManager: Running without proper bundle, skipping notification permission request")
            notificationStatus = .notDetermined
            return false
        }
        
        return await withCheckedContinuation { continuation in
            do {
                let center = UNUserNotificationCenter.current()
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        self.notificationStatus = granted ? .granted : .denied
                        continuation.resume(returning: granted)
                    }
                }
            } catch {
                print("PermissionManager: Error requesting notification permission: \(error)")
                self.notificationStatus = .notDetermined
                continuation.resume(returning: false)
            }
        }
    }
    
    // MARK: - System Settings Navigation
    func openSystemSettings(for type: PermissionType) {
        let url: URL?
        
        switch type {
        case .microphone:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .accessibility:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .notifications:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
        }
        
        if let url = url {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Onboarding Flow
    func shouldShowOnboarding() -> Bool {
        return microphoneStatus == .notDetermined || 
               accessibilityStatus == .denied // Always show onboarding if accessibility is denied since we always try to auto-paste
    }
    
    func startOnboardingFlow() {
        showingPermissionOnboarding = true
    }
    
    func completeOnboarding() {
        showingPermissionOnboarding = false
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
    }
    
    // MARK: - Status Helpers
    var allRequiredPermissionsGranted: Bool {
        return microphoneStatus == .granted
    }
    
    var canAutoPasste: Bool {
        return accessibilityStatus == .granted
    }
    
    var hasNotifications: Bool {
        return notificationStatus == .granted
    }
}

// MARK: - Permission Onboarding View
struct PermissionOnboardingView: View {
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var currentStep = 0
    private let requiredPermissions: [PermissionType] = [.microphone, .accessibility, .notifications]
    private let onCompletion: () -> Void
    
    init(onCompletion: @escaping () -> Void = {}) {
        self.onCompletion = onCompletion
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text("Welcome to lazyvoice")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Let's set up the permissions needed for the best experience")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Permission Steps
            VStack(spacing: 20) {
                ForEach(Array(requiredPermissions.enumerated()), id: \.offset) { index, permission in
                    PermissionRowView(
                        permission: permission,
                        isActive: index == currentStep,
                        isCompleted: getPermissionStatus(permission) == .granted
                    ) {
                        Task {
                            await requestPermission(permission)
                            if index < requiredPermissions.count - 1 {
                                currentStep = index + 1
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack {
                Button("Skip for Now") {
                    permissionManager.completeOnboarding()
                    onCompletion()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Continue") {
                    if allPermissionsConfigured {
                        permissionManager.completeOnboarding()
                        onCompletion()
                    } else {
                        // Move to next unconfigured permission
                        advanceToNextStep()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canContinue)
            }
        }
        .padding(40)
        .frame(width: 500, height: 600)
        .onAppear {
            permissionManager.checkAllPermissions()
        }
    }
    
    private func getPermissionStatus(_ permission: PermissionType) -> PermissionStatus {
        switch permission {
        case .microphone: return permissionManager.microphoneStatus
        case .accessibility: return permissionManager.accessibilityStatus
        case .notifications: return permissionManager.notificationStatus
        }
    }
    
    private func requestPermission(_ permission: PermissionType) async {
        switch permission {
        case .microphone:
            _ = await permissionManager.requestMicrophonePermission()
        case .accessibility:
            permissionManager.openSystemSettings(for: .accessibility)
        case .notifications:
            _ = await permissionManager.requestNotificationPermission()
        }
        
        permissionManager.checkAllPermissions()
    }
    
    private var allPermissionsConfigured: Bool {
        return permissionManager.microphoneStatus == .granted
    }
    
    private var canContinue: Bool {
        return permissionManager.microphoneStatus != .notDetermined
    }
    
    private func advanceToNextStep() {
        for (index, permission) in requiredPermissions.enumerated() {
            if getPermissionStatus(permission) == .notDetermined && index > currentStep {
                currentStep = index
                return
            }
        }
    }
}

// MARK: - Permission Row View
struct PermissionRowView: View {
    let permission: PermissionType
    let isActive: Bool
    let isCompleted: Bool
    let onRequest: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Icon
            Image(systemName: permission.icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.rawValue)
                    .font(.headline)
                    .foregroundColor(isActive ? .primary : .secondary)
                
                Text(permission.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status/Action
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else if isActive {
                Button("Grant Access") {
                    onRequest()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .border(isActive ? Color.accentColor : Color.clear, width: 1)
    }
    
    private var iconColor: Color {
        if isCompleted { return .green }
        if isActive { return .accentColor }
        return .secondary
    }
}

// MARK: - View Extension
extension View {
    func permissionOnboarding() -> some View {
        self.sheet(isPresented: .constant(PermissionManager.shared.showingPermissionOnboarding)) {
            PermissionOnboardingView()
        }
    }
} 