import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false {
        didSet {
            configureLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    @AppStorage("hotkey") private var hotkey = "⌥+⌘+Space"
    @AppStorage("maxRecordingLength") private var maxRecordingLength = 60.0
    @AppStorage("whisperModel") private var whisperModel = "tiny"
    
    // Add reference to HotkeyManager for live updates
    var hotkeyManager: HotkeyManager?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("lazyvoice Preferences")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                GroupBox("General") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Launch at login", isOn: $launchAtLogin)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Global hotkey:")
                            HStack {
                                HotkeyRecorderView(hotkey: $hotkey) { newHotkey in
                                    hotkeyManager?.updateHotkey(newHotkey)
                                }
                                
                                Button("Reset to Default") {
                                    let defaultHotkey = "⌥+⌘+Space"
                                    hotkey = defaultHotkey
                                    hotkeyManager?.updateHotkey(defaultHotkey)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Output behavior:")
                            Text("Transcribed text will be copied to clipboard and automatically pasted when possible.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                
                GroupBox("Recording") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Max recording length:")
                            Slider(value: $maxRecordingLength, in: 10...120, step: 10)
                            Text("\(Int(maxRecordingLength))s")
                                .frame(width: 40)
                        }
                    }
                    .padding()
                }
                
                GroupBox("Transcription") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Whisper model:")
                            Picker("Model", selection: $whisperModel) {
                                Text("Tiny (fastest)").tag("tiny")
                                Text("Base (balanced)").tag("base")
                                Text("Small (accurate)").tag("small")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
    
    // MARK: - Launch at Login Implementation
    private func configureLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            configureModernLaunchAtLogin(enabled: enabled)
        } else {
            configureLegacyLaunchAtLogin(enabled: enabled)
        }
    }
    
    @available(macOS 13.0, *)
    private func configureModernLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                print("Launch at login: ✅ ENABLED (modern)")
            } else {
                try SMAppService.mainApp.unregister()  
                print("Launch at login: ❌ DISABLED (modern)")
            }
        } catch {
            print("Launch at login configuration failed: \(error)")
        }
    }
    
    private func configureLegacyLaunchAtLogin(enabled: Bool) {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            print("Launch at login: ❌ FAILED - No bundle identifier")
            return
        }
        
        let success = SMLoginItemSetEnabled(bundleId as CFString, enabled)
        if success {
            print("Launch at login: \(enabled ? "✅ ENABLED" : "❌ DISABLED") (legacy)")
        } else {
            print("Launch at login: ❌ FAILED to \(enabled ? "enable" : "disable") (legacy)")
        }
    }
}

// MARK: - Hotkey Recorder Component
struct HotkeyRecorderView: View {
    @Binding var hotkey: String
    let onHotkeyChanged: (String) -> Void
    
    @State private var isRecording = false
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @State private var recordedKeyCode: UInt16 = 0
    @State private var eventMonitor: Any?
    
    var body: some View {
        Button(action: {
            if isRecording {
                cancelRecording()
            } else {
                startRecording()
            }
        }) {
            HStack {
                Text(isRecording ? "Press keys... (ESC to cancel)" : hotkey)
                    .foregroundColor(isRecording ? .secondary : .primary)
                    .frame(minWidth: 150, alignment: .leading)
                
                if isRecording {
                    Image(systemName: "record.circle")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onDisappear {
            cancelRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordedModifiers = []
        recordedKeyCode = 0
        
        // Start monitoring for key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleKeyEvent(event)
            return nil // Don't pass the event through
        }
    }
    
    private func stopRecording() {
        cleanupMonitor()
        isRecording = false
        
        // Convert recorded key combination to string
        if recordedKeyCode != 0 {
            let hotkeyString = formatHotkey(modifiers: recordedModifiers, keyCode: recordedKeyCode)
            hotkey = hotkeyString
            onHotkeyChanged(hotkeyString)
        }
    }
    
    private func cancelRecording() {
        cleanupMonitor()
        isRecording = false
        recordedModifiers = []
        recordedKeyCode = 0
    }
    
    private func cleanupMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            // Track modifier keys
            recordedModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        } else if event.type == .keyDown {
            // Check for escape key to cancel
            if event.keyCode == 53 { // Escape key
                cancelRecording()
                return
            }
            
            // Record the key and stop
            recordedKeyCode = event.keyCode
            stopRecording()
        }
    }
    
    private func formatHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        var components: [String] = []
        
        if modifiers.contains(.control) {
            components.append("⌃")
        }
        if modifiers.contains(.option) {
            components.append("⌥")
        }
        if modifiers.contains(.shift) {
            components.append("⇧")
        }
        if modifiers.contains(.command) {
            components.append("⌘")
        }
        
        // Convert keyCode to readable string
        let keyString = keyCodeToString(keyCode)
        components.append(keyString)
        
        return components.joined(separator: "+")
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 53: return "Escape"
        case 51: return "Delete"
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 50: return "`"
        default: return "Key\(keyCode)"
        }
    }
} 