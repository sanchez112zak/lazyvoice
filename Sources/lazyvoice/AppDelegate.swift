import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var menuBarView: MenuBarView?
    private var transcriptionService = TranscriptionService()
    private var hotkeyManager = HotkeyManager()
    private lazy var recordingOverlay = RecordingOverlayController(audioManager: transcriptionService.audioManager)
    private var cancellables = Set<AnyCancellable>()
    private let permissionManager = PermissionManager.shared
    
    // Recording state management
    private var isCurrentlyRecording = false
    
    // Global event monitor (needs proper cleanup)
    private var escKeyMonitor: Any?
    
    // Window management
    private var historyWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem?.button {
            statusButton.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "lazyvoice")
            statusButton.action = #selector(statusItemClicked)
            statusButton.target = self
        }
        
        // Initialize menu bar view
        menuBarView = MenuBarView()
        setupMenu()
        
        // Setup hotkey system
        setupHotkeySystem()
        
        // Setup state monitoring
        setupStateMonitoring()
        
        // Setup ESC key monitoring for cancellation
        setupEscapeKeyMonitoring()
        
        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)
        
        // Check permissions and show onboarding if needed
        checkPermissionsAndShowOnboarding()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up global event monitor
        if let monitor = escKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escKeyMonitor = nil
        }
        
        // Clean up other resources
        hotkeyManager.setEnabled(false)
        recordingOverlay.hideOverlay()
    }
    
    // MARK: - Menu Bar App Behavior
    
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        // Don't terminate the app when the last window is closed
        // This is essential for menu bar apps - they should keep running
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Handle clicking on the dock icon (if visible) or app icon
        // For menu bar apps, we typically don't want to show any windows
        // Just return true to handle the reopen event
        return true
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        // Handle window closing events
        guard let window = notification.object as? NSWindow else { return }
        
        // Clean up references when windows close
        if window === preferencesWindow {
            preferencesWindow = nil
            print("Preferences window closed")
        } else if window === historyWindow {
            historyWindow = nil
            print("History window closed")
        } else if window === onboardingWindow {
            onboardingWindow = nil
            print("Onboarding window closed - app will continue running")
            
            // Mark onboarding as completed when window closes
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        }
        
        // The app should continue running even after windows close
        // This is handled by applicationShouldTerminateAfterLastWindowClosed returning false
    }
    
    @objc func statusItemClicked() {
        // Handle status item click
        print("Status item clicked")
    }
    
    private func setupMenu() {
        updateMenu()
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        
        // Dynamic menu items based on recording state
        if isCurrentlyRecording {
            menu.addItem(NSMenuItem(title: "🔴 Recording...", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "s"))
            menu.addItem(NSMenuItem(title: "Cancel Recording (ESC)", action: #selector(cancelRecordingMenu), keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Start Recording (\(hotkeyManager.hotkey))", action: #selector(startRecording), keyEquivalent: "r"))
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Recent transcriptions submenu
        let recentTranscriptions = transcriptionService.historyManager.recentTranscriptions(count: 5)
        if !recentTranscriptions.isEmpty {
            let historySubmenu = NSMenu()
            
            for transcription in recentTranscriptions {
                let truncatedText = String(transcription.text.prefix(50)) + (transcription.text.count > 50 ? "..." : "")
                let item = NSMenuItem(title: truncatedText, action: #selector(copyRecentTranscription(_:)), keyEquivalent: "")
                item.representedObject = transcription
                item.target = self
                historySubmenu.addItem(item)
            }
            
            historySubmenu.addItem(NSMenuItem.separator())
            historySubmenu.addItem(NSMenuItem(title: "Show All...", action: #selector(showHistory), keyEquivalent: ""))
            
            let historyMenuItem = NSMenuItem(title: "Recent Transcriptions", action: nil, keyEquivalent: "")
            historyMenuItem.submenu = historySubmenu
            menu.addItem(historyMenuItem)
        }
        
        menu.addItem(NSMenuItem(title: "History", action: #selector(showHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func startRecording() {
        guard !isCurrentlyRecording else { return }
        
        print("Start recording")
        isCurrentlyRecording = true
        
        // Show live waveform overlay
        recordingOverlay.showOverlay()
        
        // Update status icon manually
        updateStatusIcon(recording: true, transcribing: false)
        
        transcriptionService.startRecording()
        updateMenu()
    }
    
    @objc func stopRecording() {
        guard isCurrentlyRecording else { return }
        
        print("Stop recording")
        isCurrentlyRecording = false
        
        // First stop recording so any final Combine updates are delivered
        transcriptionService.stopRecording()
        
        // Now it is safe to remove the overlay (after Combine updates).
        // Delay slightly to guarantee the main-thread updates from AudioManager have been delivered.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.recordingOverlay.hideOverlay()
        }
        
        // Update status icon manually  
        updateStatusIcon(recording: false, transcribing: false)
        updateMenu()
    }
    
    @objc func cancelRecordingMenu() {
        cancelRecording()
    }
    
    private func toggleRecording() {
        if isCurrentlyRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func cancelRecording() {
        guard isCurrentlyRecording else { return }
        
        print("Recording cancelled")
        isCurrentlyRecording = false
        // Stop recording first
        transcriptionService.stopRecording()
        
        // Hide live waveform overlay afterwards with a slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.recordingOverlay.hideOverlay()
        }
        updateMenu()
    }
    
    @objc func showHistory() {
        print("Show history")
        
        // Close existing history window if open
        historyWindow?.close()
        
        // Create history view with error handling
        let historyView = HistoryView(historyManager: transcriptionService.historyManager)
            .errorAlert()
        
        // Create and configure window
        historyWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        historyWindow?.title = "Transcription History"
        historyWindow?.contentView = NSHostingView(rootView: historyView)
        historyWindow?.center()
        historyWindow?.makeKeyAndOrderFront(nil)
        
        // Ensure window closes properly without terminating app
        historyWindow?.isReleasedWhenClosed = false
        historyWindow?.delegate = self
        
        // Bring app to front when showing history
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showPreferences() {
        print("Show preferences")
        
        // Close existing preferences window if open
        preferencesWindow?.close()
        preferencesWindow = nil
        
        // Create preferences view with hotkey manager reference and error handling
        let preferencesView = PreferencesView(hotkeyManager: hotkeyManager)
            .errorAlert()
        
        // Create and configure window
        preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        preferencesWindow?.title = "Preferences"
        preferencesWindow?.contentView = NSHostingView(rootView: preferencesView)
        preferencesWindow?.center()
        preferencesWindow?.makeKeyAndOrderFront(nil)
        
        // Ensure window closes properly without terminating app
        preferencesWindow?.isReleasedWhenClosed = false
        
        // Set up window delegate to handle close events properly
        preferencesWindow?.delegate = self
        
        // Bring app to front when showing preferences
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func copyRecentTranscription(_ sender: NSMenuItem) {
        guard let transcription = sender.representedObject as? Transcription else { return }
        transcriptionService.historyManager.copyToClipboard(transcription)
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Phase 2: Hotkey System Setup
    
    private func setupHotkeySystem() {
        // Set up global hotkey callback with weak reference
        hotkeyManager.onHotkeyPressed = { [weak self] in
            print("Global hotkey pressed!")
            self?.toggleRecording()
        }
        
        print("Hotkey system initialized with hotkey: \(hotkeyManager.hotkey)")
    }
    
    private func setupStateMonitoring() {
        // Simplified state monitoring to avoid memory issues
        // Remove complex Combine publishers that might cause crashes
        print("State monitoring disabled to prevent crashes")
    }
    
    private func updateStatusIcon(recording: Bool, transcribing: Bool) {
        guard let statusButton = statusItem?.button else { return }
        
        if recording {
            statusButton.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
        } else if transcribing {
            statusButton.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Transcribing")
        } else {
            statusButton.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "lazyvoice")
        }
    }
    
    private func setupEscapeKeyMonitoring() {
        // Clean up existing monitor first
        if let monitor = escKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Setup ESC key monitoring with proper cleanup
        escKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.cancelRecording()
            }
        }
    }
    
    // MARK: - Permission Management
    private func checkPermissionsAndShowOnboarding() {
        // Check if this is the first launch or if onboarding hasn't been completed
        let onboardingCompleted = UserDefaults.standard.bool(forKey: "onboardingCompleted")
        
        if !onboardingCompleted || permissionManager.shouldShowOnboarding() {
            // Delay onboarding slightly to ensure app is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.permissionManager.startOnboardingFlow()
                self.showPermissionOnboarding()
            }
        }
    }
    
    private func showPermissionOnboarding() {
        // Close existing onboarding window if open
        onboardingWindow?.close()
        onboardingWindow = nil
        
        // Create permission onboarding window with completion callback
        let onboardingView = PermissionOnboardingView { [weak self] in
            // This callback is called when onboarding is completed
            DispatchQueue.main.async {
                self?.onboardingWindow?.close()
            }
        }
        
        onboardingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        onboardingWindow?.title = "lazyvoice Setup"
        onboardingWindow?.contentView = NSHostingView(rootView: onboardingView)
        onboardingWindow?.center()
        onboardingWindow?.makeKeyAndOrderFront(nil)
        onboardingWindow?.level = .floating // Show above other windows
        
        // Ensure window closes properly without terminating app
        onboardingWindow?.isReleasedWhenClosed = false
        onboardingWindow?.delegate = self
        
        // Bring app to front for onboarding
        NSApp.activate(ignoringOtherApps: true)
    }
} 