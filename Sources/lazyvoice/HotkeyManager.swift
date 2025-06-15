import Foundation
import Carbon
import Combine

class HotkeyManager: ObservableObject {
    @Published var isEnabled = true
    @Published var hotkey = "⌥+⌘+Space" // Default hotkey combination
    
    private var hotkeyRef: EventHotKeyRef? = nil
    private var eventHandler: EventHandlerRef? = nil
    private let hotkeyID: EventHotKeyID = EventHotKeyID(signature: OSType(0x54584954), id: 1) // 'QXIT'
    private let errorManager = ErrorManager.shared
    
    // Callback closure to notify when hotkey is pressed
    var onHotkeyPressed: (() -> Void)?
    
    init() {
        // Load saved hotkey from UserDefaults
        if let savedHotkey = UserDefaults.standard.string(forKey: "hotkey") {
            hotkey = savedHotkey
        }
        setupGlobalHotkey()
    }
    
    deinit {
        unregisterHotkey()
    }
    
    private func setupGlobalHotkey() {
        guard isEnabled else { return }
        
        // Parse the current hotkey string
        guard let (keyCode, modifiers) = parseHotkeyString(hotkey) else {
            print("Failed to parse hotkey: \(hotkey)")
            errorManager.handleError(.hotkeyRegistrationFailed("Invalid hotkey format: \(hotkey)"))
            return
        }
        
        registerHotkey(keyCode: keyCode, modifiers: modifiers)
    }
    
    private func registerHotkey(keyCode: UInt32, modifiers: UInt32) {
        // Unregister existing hotkey first
        unregisterHotkey()
        
        // Install event handler
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let eventCallback: EventHandlerProcPtr = { (nextHandler, theEvent, userData) -> OSStatus in
            // Safely get the HotkeyManager instance from userData
            guard let userData = userData else { return noErr }
            let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(theEvent, 
                                         EventParamName(kEventParamDirectObject), 
                                         EventParamType(typeEventHotKeyID), 
                                         nil, 
                                         MemoryLayout<EventHotKeyID>.size, 
                                         nil, 
                                         &hotKeyID)
            
            if status == noErr && hotKeyID.id == hotkeyManager.hotkeyID.id {
                DispatchQueue.main.async {
                    hotkeyManager.onHotkeyPressed?()
                }
            }
            
            return noErr
        }
        
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), 
                                       eventCallback, 
                                       1, 
                                       &eventSpec, 
                                       userData, 
                                       &eventHandler)
        
        if status != noErr {
            print("Failed to install hotkey event handler: \(status)")
            errorManager.handleError(.hotkeyRegistrationFailed("Failed to install event handler (error: \(status))"))
            return
        }
        
        // Register the hotkey
        let hotkeyStatus = RegisterEventHotKey(keyCode, 
                                             modifiers, 
                                             hotkeyID, 
                                             GetApplicationEventTarget(), 
                                             0, 
                                             &hotkeyRef)
        
        if hotkeyStatus == noErr {
            print("Global hotkey registered successfully: \(hotkey)")
        } else {
            print("Failed to register global hotkey: \(hotkeyStatus)")
            let errorMessage = hotkeyStatus == Int32(eventHotKeyExistsErr) ? 
                "Hotkey '\(hotkey)' is already in use by another application" : 
                "Failed to register hotkey (error: \(hotkeyStatus))"
            errorManager.handleError(.hotkeyRegistrationFailed(errorMessage))
        }
    }
    
    private func unregisterHotkey() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    func updateHotkey(_ newHotkey: String) {
        hotkey = newHotkey
        
        // Save to UserDefaults for persistence
        UserDefaults.standard.set(newHotkey, forKey: "hotkey")
        
        // Parse the new hotkey string and re-register
        setupGlobalHotkey()
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        
        if enabled {
            setupGlobalHotkey()
        } else {
            unregisterHotkey()
        }
    }
}

// MARK: - Hotkey String Parsing Extensions
extension HotkeyManager {
    private func parseHotkeyString(_ hotkeyString: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        // Basic implementation for common hotkey patterns
        // TODO: Expand this for more comprehensive hotkey parsing
        
        let components = hotkeyString.components(separatedBy: "+")
        var modifiers: UInt32 = 0
        var keyCode: UInt32 = 0
        
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            
            switch trimmed {
            case "⌘", "Cmd", "Command":
                modifiers |= UInt32(cmdKey)
            case "⌥", "Alt", "Option":
                modifiers |= UInt32(optionKey)
            case "⌃", "Ctrl", "Control":
                modifiers |= UInt32(controlKey)
            case "⇧", "Shift":
                modifiers |= UInt32(shiftKey)
            case "V":
                keyCode = UInt32(kVK_ANSI_V)
            case "R":
                keyCode = UInt32(kVK_ANSI_R)
            case "T":
                keyCode = UInt32(kVK_ANSI_T)
            case "Space":
                keyCode = UInt32(kVK_Space)
            default:
                // Try to parse single character keys
                if let char = trimmed.first, trimmed.count == 1 {
                    keyCode = UInt32(char.asciiValue ?? 0)
                }
            }
        }
        
        return keyCode > 0 ? (keyCode, modifiers) : nil
    }
} 