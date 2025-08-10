import Foundation
import Carbon
import AppKit

class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private let callback: () -> Void
    
    // Default: Cmd+Shift+Space
    private let keyCode: UInt32 = 49  // Space
    private let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
        registerHotKey()
    }
    
    deinit {
        unregisterHotKey()
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
        
        print("Registered global hotkey: ⌘⇧Space")
    }
    
    private func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
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