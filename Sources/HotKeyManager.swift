import Foundation
import Carbon
import AppKit

class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private let callback: () -> Void
    
    // Current hotkey configuration
    private var keyCode: UInt32 = 49  // Space
    private var modifiers: UInt32 = UInt32(optionKey)
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
        loadHotKeySettings()
        registerHotKey()
        
        // Listen for hotkey changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotKeySettingsChanged),
            name: .hotKeyChanged,
            object: nil
        )
    }
    
    deinit {
        unregisterHotKey()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func loadHotKeySettings() {
        let modifierValue = UserDefaults.standard.integer(forKey: "hotKeyModifier")
        let keyCodeValue = UserDefaults.standard.integer(forKey: "hotKeyCode")
        
        // Convert modifier value to Carbon modifiers
        switch modifierValue {
        case 0: // Option only
            modifiers = UInt32(optionKey)
        case 1: // Cmd+Shift
            modifiers = UInt32(cmdKey | shiftKey)
        case 2: // Cmd+Option
            modifiers = UInt32(cmdKey | optionKey)
        case 3: // Cmd+Control
            modifiers = UInt32(cmdKey | controlKey)
        case 4: // Option+Shift
            modifiers = UInt32(optionKey | shiftKey)
        default:
            modifiers = UInt32(optionKey)
        }
        
        // Use custom key code or default to Space
        keyCode = keyCodeValue > 0 ? UInt32(keyCodeValue) : 49
    }
    
    @objc private func hotKeySettingsChanged() {
        unregisterHotKey()
        loadHotKeySettings()
        registerHotKey()
    }
    
    private func registerHotKey() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.callback()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("SWLT".fourCharCodeValue)
        hotKeyID.id = 1
        
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        let shortcutString = getShortcutString()
        print("Registered global hotkey: \(shortcutString)")
    }
    
    private func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
    
    private func getShortcutString() -> String {
        var modifierString = ""
        if modifiers & UInt32(cmdKey) != 0 { modifierString += "⌘" }
        if modifiers & UInt32(optionKey) != 0 { modifierString += "⌥" }
        if modifiers & UInt32(controlKey) != 0 { modifierString += "⌃" }
        if modifiers & UInt32(shiftKey) != 0 { modifierString += "⇧" }
        
        let keyString: String
        switch keyCode {
        case 49: keyString = "Space"
        case 15: keyString = "R"
        case 17: keyString = "T"
        case 46: keyString = "M"
        case 9: keyString = "V"
        default: keyString = "Key(\(keyCode))"
        }
        
        return "\(modifierString)\(keyString)"
    }
}

extension String {
    var fourCharCodeValue: UInt32 {
        var result: UInt32 = 0
        for char in self.utf8 {
            result = result << 8 + UInt32(char)
        }
        return result
    }
}