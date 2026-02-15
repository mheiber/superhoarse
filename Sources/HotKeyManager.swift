import Foundation
import Carbon
import AppKit

// =============================================================================
// HotKeyManager: Global Hotkey Registration with Key-Down AND Key-Up Detection
// =============================================================================
//
// ARCHITECTURE OVERVIEW (READ THIS BEFORE MODIFYING):
//
// This manager supports TWO separate hotkeys with independent modifier keys:
//   1. "Toggle" hotkey (TRIGGER KEY) — used for tap-to-toggle recording
//   2. "PTT" hotkey (TRIGGER PUSH-TO-TALK) — used for hold-to-record (push-to-talk)
//
// By default, both hotkeys use the SAME key (e.g., Space). When they are the same,
// we register only ONE Carbon hotkey and use timing-based logic in AppState to
// distinguish a "tap" (< 200ms) from a "hold" (>= 200ms). See AppState.swift for
// that logic.
//
// When the user configures DIFFERENT keys for toggle vs PTT, we register TWO
// separate Carbon hotkeys. In that case, no timing ambiguity exists: the toggle
// key always toggles, the PTT key always does hold-to-record.
//
// CARBON EVENT HANDLING:
// We register for BOTH kEventHotKeyPressed AND kEventHotKeyReleased. This is
// essential for detecting when the user releases the PTT key. The old code only
// handled kEventHotKeyPressed, which made hold-to-record impossible.
//
// The event handler dispatches to onKeyDown/onKeyUp closures, passing a HotKeyID
// so AppState knows WHICH hotkey was pressed (toggle vs PTT vs shared).
//
// =============================================================================

/// Identifies which hotkey was pressed/released.
/// When toggle and PTT keys are the same, `.shared` is used.
/// When they are different, `.toggle` or `.ptt` is used.
enum HotKeyIdentity {
    case shared   // Toggle and PTT are the same key — AppState uses timing to disambiguate
    case toggle   // Separate toggle key — always means tap-to-toggle
    case ptt      // Separate PTT key — always means hold-to-record
}

class HotKeyManager {
    // Carbon hotkey references. We may have one or two depending on configuration.
    private var toggleHotKeyRef: EventHotKeyRef?
    private var pttHotKeyRef: EventHotKeyRef?

    // Event handler reference (needed for cleanup)
    private var eventHandlerRef: EventHandlerRef?

    // Callbacks for key-down and key-up events.
    // The HotKeyIdentity tells AppState which key was involved.
    private let onKeyDown: (HotKeyIdentity) -> Void
    private let onKeyUp: (HotKeyIdentity) -> Void

    // Current hotkey configuration
    private var keyCode: UInt32 = 49         // Toggle trigger key (default: Space)
    private var pttKeyCode: UInt32 = 49      // PTT trigger key (default: Space, same as toggle)
    private var modifiers: UInt32 = UInt32(optionKey)
    private var modifiersPTT: UInt32 = UInt32(optionKey)  // PTT modifier (default: same as toggle)

    // Carbon hotkey IDs — these distinguish which hotkey fired in the event handler.
    // ID 1 = shared (both keys are the same) or toggle-only
    // ID 2 = PTT-only (when keys are different)
    private static let toggleHotKeyIDValue: UInt32 = 1
    private static let pttHotKeyIDValue: UInt32 = 2

    init(onKeyDown: @escaping (HotKeyIdentity) -> Void, onKeyUp: @escaping (HotKeyIdentity) -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        loadHotKeySettings()
        registerHotKeys()

        // Listen for hotkey changes from the settings UI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotKeySettingsChanged),
            name: .hotKeyChanged,
            object: nil
        )
    }

    deinit {
        unregisterHotKeys()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Settings

    /// Converts a UserDefaults modifier value (0-4) to Carbon modifier flags.
    private static func carbonModifiers(for value: Int) -> UInt32 {
        switch value {
        case 0: return UInt32(optionKey)
        case 1: return UInt32(cmdKey | shiftKey)
        case 2: return UInt32(cmdKey | optionKey)
        case 3: return UInt32(cmdKey | controlKey)
        case 4: return UInt32(optionKey | shiftKey)
        default: return UInt32(optionKey)
        }
    }

    private func loadHotKeySettings() {
        let modifierValue = UserDefaults.standard.integer(forKey: "hotKeyModifier")
        let keyCodeValue = UserDefaults.standard.integer(forKey: "hotKeyCode")
        let pttKeyCodeValue = UserDefaults.standard.integer(forKey: "hotKeyCodePTT")

        // Convert modifier values to Carbon modifier flags
        modifiers = HotKeyManager.carbonModifiers(for: modifierValue)

        // PTT modifier: if the key was never set in UserDefaults, fall back to toggle modifier.
        // We check object(forKey:) because integer(forKey:) returns 0 for unset keys, and
        // 0 is a valid modifier value (Option key). The UI stores -1 as the @AppStorage default,
        // and any negative value also means "use toggle modifier."
        if let pttModObj = UserDefaults.standard.object(forKey: "hotKeyModifierPTT") as? Int, pttModObj >= 0 {
            modifiersPTT = HotKeyManager.carbonModifiers(for: pttModObj)
        } else {
            modifiersPTT = modifiers
        }

        // Use custom key codes or default to Space (49)
        keyCode = keyCodeValue > 0 ? UInt32(keyCodeValue) : 49

        // PTT key defaults to the same as the toggle key if not explicitly set.
        // UserDefaults returns 0 for unset integers, so we treat 0 as "use toggle key".
        pttKeyCode = pttKeyCodeValue > 0 ? UInt32(pttKeyCodeValue) : keyCode
    }

    @objc private func hotKeySettingsChanged() {
        unregisterHotKeys()
        loadHotKeySettings()
        registerHotKeys()
    }

    // MARK: - Registration

    /// Whether the toggle key and PTT key are configured to the same key AND modifier.
    /// When true, we register one hotkey and use timing logic in AppState.
    /// When false, we register two separate hotkeys with unambiguous behavior.
    var keysAreShared: Bool {
        return keyCode == pttKeyCode && modifiers == modifiersPTT
    }

    private func registerHotKeys() {
        // Register the Carbon event handler for BOTH key-down AND key-up.
        // This is a single handler that dispatches based on event kind and hotkey ID.
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased))
        ]

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (handler, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleCarbonEvent(event)
            },
            2, // Two event types: pressed + released
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        if keysAreShared {
            // Same key for both toggle and PTT — register one hotkey with "shared" ID
            var hotKeyID = EventHotKeyID()
            hotKeyID.signature = OSType("SWLT".fourCharCodeValue)
            hotKeyID.id = HotKeyManager.toggleHotKeyIDValue
            RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &toggleHotKeyRef)

            let shortcutString = getShortcutString(forKeyCode: keyCode, withModifiers: modifiers)
            print("Registered shared hotkey (toggle+PTT): \(shortcutString)")
        } else {
            // Different keys — register two separate hotkeys

            // Toggle hotkey (ID 1)
            var toggleID = EventHotKeyID()
            toggleID.signature = OSType("SWLT".fourCharCodeValue)
            toggleID.id = HotKeyManager.toggleHotKeyIDValue
            RegisterEventHotKey(keyCode, modifiers, toggleID, GetApplicationEventTarget(), 0, &toggleHotKeyRef)

            // PTT hotkey (ID 2)
            var pttID = EventHotKeyID()
            pttID.signature = OSType("SWLT".fourCharCodeValue)
            pttID.id = HotKeyManager.pttHotKeyIDValue
            RegisterEventHotKey(pttKeyCode, modifiersPTT, pttID, GetApplicationEventTarget(), 0, &pttHotKeyRef)

            let toggleStr = getShortcutString(forKeyCode: keyCode, withModifiers: modifiers)
            let pttStr = getShortcutString(forKeyCode: pttKeyCode, withModifiers: modifiersPTT)
            print("Registered separate hotkeys — toggle: \(toggleStr), PTT: \(pttStr)")
        }
    }

    private func unregisterHotKeys() {
        if let ref = toggleHotKeyRef {
            UnregisterEventHotKey(ref)
            toggleHotKeyRef = nil
        }
        if let ref = pttHotKeyRef {
            UnregisterEventHotKey(ref)
            pttHotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }

    // MARK: - Event Handling

    /// Handles Carbon hotkey events (both pressed and released).
    /// Extracts the hotkey ID to determine which key fired, then dispatches
    /// to the appropriate onKeyDown/onKeyUp callback with the correct identity.
    private func handleCarbonEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }

        // Extract which hotkey fired from the event
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else { return status }

        // Determine the identity based on the hotkey ID and whether keys are shared
        let identity: HotKeyIdentity
        if keysAreShared {
            identity = .shared
        } else if hotKeyID.id == HotKeyManager.pttHotKeyIDValue {
            identity = .ptt
        } else {
            identity = .toggle
        }

        // Dispatch based on event kind (pressed vs released)
        let eventKind = GetEventKind(event)
        if eventKind == UInt32(kEventHotKeyPressed) {
            onKeyDown(identity)
        } else if eventKind == UInt32(kEventHotKeyReleased) {
            onKeyUp(identity)
        }

        return noErr
    }

    // MARK: - Display Helpers

    private func getShortcutString(forKeyCode code: UInt32, withModifiers mods: UInt32) -> String {
        var modifierString = ""
        if mods & UInt32(cmdKey) != 0 { modifierString += "⌘" }
        if mods & UInt32(optionKey) != 0 { modifierString += "⌥" }
        if mods & UInt32(controlKey) != 0 { modifierString += "⌃" }
        if mods & UInt32(shiftKey) != 0 { modifierString += "⇧" }

        let keyString: String
        switch code {
        case 49: keyString = "Space"
        case 15: keyString = "R"
        case 17: keyString = "T"
        case 46: keyString = "M"
        case 9: keyString = "V"
        default: keyString = "Key(\(code))"
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
