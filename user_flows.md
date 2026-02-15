# User Flows - Test Plan

## 1. First Launch & Accessibility Permission Flow

### Setup
- Fresh install or revoke accessibility permissions in System Preferences
- Launch app

### Expected Behavior
1. App launches with dock visibility based on setting (default: shows in Dock)
2. Settings window opens automatically if accessibility permissions not granted
3. Menu bar icon shows ⚠️ "OPEN SETTINGS" (orange text) if no permissions
4. Settings window displays permission request UI

### Grant Permission Flow
1. Click "Grant Accessibility Permission" in settings
2. System Preferences opens to Privacy & Security > Accessibility
3. Toggle app permission ON
4. Return to app - permission status updates automatically (2s polling)
5. Menu bar icon changes to ⚡ "OPEN SETTINGS" (purple text)
6. Settings window can be closed manually

### Subsequent Launches (With Permission)
1. App launches with dock visibility based on setting
2. Settings window does NOT open automatically
3. Menu bar icon shows ⚡ "OPEN SETTINGS" (purple)
4. If app shows in dock, clicking dock icon opens settings

### Permission Revocation Flow
1. User manually revokes accessibility permissions in System Preferences (Privacy & Security > Accessibility)
2. Within 2 seconds, app detects permission loss via continuous monitoring
3. Menu bar icon changes from ⚡ purple to ⚠️ orange "OPEN SETTINGS"
4. Settings window automatically shows permission request UI if open
5. AccessibilityPermissionView appears with "GRANT PERMISSION" button
6. User can click "Grant Permission" to restore permissions
7. Behavior is identical to first launch without permissions

## 2. Core Recording & Transcription Flow

### Prerequisites
- Accessibility permission granted
- Microphone permission granted
- Speech engine initialized (check status in settings)

### Happy Path
1. Press hotkey (default: ⌘⇧Space)
2. Listening indicator appears (floating window, top of screen)
3. Speak clearly for 1-3 seconds
4. Release hotkey OR press again to stop
5. Listening indicator disappears
6. Text appears in focused application
7. If "Copy to Clipboard" is enabled in settings, text is also copied to clipboard

### Audio Level Feedback
1. During recording, listening indicator shows real-time audio levels
2. Visual feedback confirms microphone is capturing audio
3. No audio = flat line, speaking = animated levels

## 3. Hotkey Management Flow

### Default Hotkey
- ⌘⇧Space triggers recording
- Works globally across all applications

### Custom Hotkey Setup
1. Open settings window
2. Navigate to hotkey configuration section
3. Select different modifier combination (⌘⌥, ⌘⌃, ⌥⇧)
4. Select different key (R, T, M, V, Space)
5. Hotkey updates immediately
6. Test new combination works globally

### Hotkey Display
- Current hotkey shown in settings window
- Format: ⌘⇧Space, ⌘⌥R, etc.

## 4. Permission States & Fallbacks

### Continuous Permission Monitoring
1. App monitors accessibility permissions every 2 seconds throughout its lifecycle
2. Permission changes are detected automatically (grant/revoke)
3. UI updates immediately when permissions change
4. Menu bar icon reflects current permission state in real-time
5. No user action required to detect permission changes

### No Accessibility Permission (Clipboard Enabled)
1. Record audio successfully
2. Text transcribed and copied to clipboard
3. Paste notification window appears (center screen) showing "⌘V"
4. Notification dismisses after timeout or click

### No Accessibility Permission (Clipboard Disabled - Default)
1. Record audio successfully
2. Text transcribed but NOT copied to clipboard
3. Accessibility notification window appears (center screen)
4. Shows "ACCESSIBILITY REQUIRED" with "Grant permission to insert text"
5. "OPEN SETTINGS" button opens settings window directly
6. Notification auto-dismisses after 5 seconds, or on tap, or after clicking button

### No Microphone Permission
1. Hotkey pressed
2. No listening indicator appears
3. Recording fails silently
4. No transcription occurs

## 5. Menu Bar Interactions

### Status Indicators
- ⚡ Purple "OPEN SETTINGS" = has accessibility permission
- ⚠️ Orange "OPEN SETTINGS" = missing accessibility permission

### Click Behavior
- **Left-click** menu bar icon → opens settings window directly
- **Right-click** menu bar icon → shows dropdown menu

### Menu Actions (Right-Click)
1. Right-click menu bar icon
2. Menu shows: "OPEN SETTINGS", separator, "QUIT SUPERHOARSE"
3. Click "OPEN SETTINGS" → opens settings window
4. Click "QUIT SUPERHOARSE" → terminates app

## 6. Recording Cancellation Flow

### Escape Key Cancellation
1. Start recording with hotkey
2. Press Escape key during recording
3. Recording stops immediately
4. No transcription occurs
5. Listening indicator disappears
6. No text insertion or clipboard update

### Manual Stop
1. Start recording with hotkey
2. Press hotkey again to stop
3. Normal transcription flow continues

## 7. Error Handling Flows

### Short Audio (< 0.5s)
1. Press hotkey briefly
2. Release quickly (< 0.5 seconds)
3. Recording captured but filtered out
4. No transcription result
5. No error shown to user

### Silent Audio
1. Press hotkey
2. Don't speak (only background noise)
3. Stop recording
4. No transcription result
5. No text insertion

### Engine Initialization Failure
1. Launch app
2. Settings show "Engine not initialized" status
3. Recording attempts fail silently
4. Status updates when engine becomes available

### Transcription Timeout
1. Very long recording (> 30 seconds processing)
2. Transcription times out
3. No result returned
4. User can attempt new recording

## 8. Settings Window Management

### Window Behavior
1. Settings window can be opened/closed multiple times
2. Window state persists (position, size within bounds)
3. Window doesn't prevent app termination when closed
4. Only one settings window instance at a time

### Configuration Persistence
1. Change hotkey settings
2. Close and reopen app
3. Settings preserved across sessions
4. UserDefaults storage working correctly

## 9. Speech Engine Management

### Engine Status Check
1. Open settings
2. Check engine initialization status
3. Status shows "Initialized" or "Not Initialized"
4. Engine type displayed (currently: Parakeet)

### Engine Switching (Future)
- Currently only Parakeet engine available
- Framework supports multiple engines
- Settings UI prepared for engine selection

## 10. Multi-App Text Insertion

### Application Switching
1. Focus different apps (TextEdit, Notes, Terminal, etc.)
2. Use hotkey in each app
3. Text inserts at cursor position in focused app
4. Works across all applications that accept text input

## 11. App Preferences Management

### Launch at Startup Setting
1. Open settings window
2. Navigate to "APP PREFERENCES" section
3. Toggle "LAUNCH AT STARTUP" (default: OFF)
4. Setting persists across app restarts
5. When enabled, user must manually add app to Login Items in System Preferences

### Show in Dock Setting
1. Open settings window
2. Navigate to "APP PREFERENCES" section  
3. Toggle "SHOW IN DOCK" (default: ON)
4. App activation policy updates immediately
5. When enabled:
   - App icon appears in Dock
   - Clicking dock icon opens settings window
   - App behaves as regular application
6. When disabled:
   - App runs as menu bar only (accessory mode)
   - No dock icon visible
   - Only accessible via menu bar

### Settings Window Behavior
1. Settings window can be opened/closed without quitting app
2. Closing settings window keeps app running in background
3. Settings accessed via menu bar item or dock icon (if visible)
4. All preference changes take effect immediately

### Copy to Clipboard Setting
1. Open settings window
2. Navigate to "APP PREFERENCES" section
3. Toggle "COPY TO CLIPBOARD" (default: OFF)
4. When enabled:
   - Transcribed text is copied to system clipboard after each transcription
   - "COPIED TO CLIPBOARD" label appears in recording status section
   - If accessibility permission denied, paste notification (⌘V) appears
5. When disabled (default):
   - Text is NOT copied to clipboard
   - No "COPIED TO CLIPBOARD" label shown
   - If accessibility permission denied, accessibility notification appears instead
   - Notification shows "ACCESSIBILITY REQUIRED" and "Open Settings to grant permission"
6. Setting persists across app restarts

## Test Data Scenarios

### Audio Content
- Clear speech: "Hello world this is a test"
- Numbers: "The year is 2024"
- Punctuation: "Hello, world! How are you?"
- Mixed case: "iPhone and MacBook"

### Edge Cases
- Very quiet speech
- Background noise present
- Multiple speakers
- Non-English words
- Technical terms

## 12. Permission Revocation Testing

### Test Scenario: Grant and Revoke Permissions
1. **Initial State**: Launch app without accessibility permissions
2. **Grant Permission**: 
   - Verify ⚠️ orange menu bar icon and permission request UI appears
   - Click "Grant Permission" button
   - Grant permission in System Preferences
   - Verify ⚡ purple menu bar icon and UI updates within 2 seconds
3. **Revoke Permission**:
   - Go to System Preferences > Privacy & Security > Accessibility
   - Toggle app permission OFF
   - Return to app and wait up to 2 seconds
   - Verify ⚡ purple menu bar icon changes to ⚠️ orange
   - Verify permission request UI reappears (identical to initial state)
4. **Re-grant Permission**:
   - Click "Grant Permission" button again
   - Toggle app permission ON in System Preferences
   - Verify app returns to granted permission state
   - Verify functionality works normally

### Critical Test Points
- Permission state detection happens automatically within 2 seconds
- UI is identical whether permissions were never granted or were revoked
- No difference in behavior between fresh install and revoked permissions
- Menu bar icon accurately reflects current permission state at all times

