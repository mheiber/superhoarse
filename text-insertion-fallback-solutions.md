# Text Insertion Fallback Solutions for Superhoarse

## Problem Analysis

When a user's cursor is not positioned in a valid text insertion location (e.g., in read-only areas, system dialogs, non-text fields, or certain applications), the current Superhoarse implementation loses dictation output entirely. The `insertTextAtCursor` method in `AppState.swift:477` uses a simple CGEvent posting mechanism without validation, leading to silent failures.

**Current Implementation Issues:**
- No validation of cursor position before text insertion
- No feedback when insertion fails
- Text is lost if accessibility event posting fails
- Only clipboard copying as implicit fallback

## Solution 1: Pre-Insertion Cursor Validation

### Implementation Strategy
Implement accessibility API checks to validate cursor position before attempting text insertion.

### Technical Approach
```swift
private func validateCursorPosition() -> TextInsertionCapability {
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
        return .noTarget
    }
    
    // Get the accessibility element at the cursor
    let systemWideElement = AXUIElementCreateSystemWide()
    var focusedElement: AXUIElement?
    
    if AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
       let element = focusedElement {
        
        // Check if element supports text insertion
        var role: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success {
            let roleString = role as? String ?? ""
            
            // Check for text-insertable roles
            if ["AXTextField", "AXTextArea", "AXComboBox"].contains(roleString) {
                
                // Verify element is editable
                var isEditable: AnyObject?
                if AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &isEditable) == .success,
                   let enabled = isEditable as? Bool, enabled {
                    
                    // Check for text selection range (cursor position)
                    var selectedRange: AnyObject?
                    if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success {
                        return .directInsertion
                    }
                }
            }
        }
    }
    
    return .requiresFallback
}

enum TextInsertionCapability {
    case directInsertion
    case requiresFallback
    case noTarget
}
```

### Fallback Chain
1. **Primary**: Direct text insertion (current method)
2. **Secondary**: Simulate Cmd+V paste operation
3. **Tertiary**: Show user notification with clipboard status

### Advantages
- Prevents silent failures
- Maintains current successful insertion patterns
- Minimal performance impact with caching

### Implementation Complexity
**Medium** - Requires accessibility API integration and testing across applications

---

## Solution 2: Progressive Fallback Strategy

### Implementation Strategy
Implement a multi-tier fallback system that attempts different insertion methods in order of preference.

### Technical Approach
```swift
private func insertTextWithFallback(_ text: String) {
    // Tier 1: Validated direct insertion
    if validateCursorPosition() == .directInsertion {
        if attemptDirectInsertion(text) {
            logSuccess("Direct insertion successful")
            return
        }
    }
    
    // Tier 2: Simulated paste operation
    copyToClipboard(text)
    if attemptPasteOperation() {
        logSuccess("Paste operation successful")
        showTemporaryNotification("Text pasted via clipboard")
        return
    }
    
    // Tier 3: Application-specific insertion
    if let frontmostApp = NSWorkspace.shared.frontmostApplication {
        if attemptAppSpecificInsertion(text, app: frontmostApp) {
            logSuccess("App-specific insertion successful")
            return
        }
    }
    
    // Tier 4: User notification with manual paste option
    showPersistentNotification(
        title: "Text Ready to Paste",
        body: "'\(text.prefix(50))...' copied to clipboard. Paste with ⌘V",
        actions: ["Paste Now", "Dismiss"]
    )
}

private func attemptPasteOperation() -> Bool {
    // Create and post Cmd+V key combination
    guard let cmdVDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true) else { return false }
    cmdVDown.flags = .maskCommand
    cmdVDown.post(tap: .cghidEventTap)
    
    // Brief delay for key up event
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
        guard let cmdVUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else { return }
        cmdVUp.flags = .maskCommand
        cmdVUp.post(tap: .cghidEventTap)
    }
    
    return true
}

private func attemptAppSpecificInsertion(_ text: String, app: NSRunningApplication) -> Bool {
    // Handle known problematic applications
    switch app.bundleIdentifier {
    case "com.apple.Terminal", "com.googlecode.iterm2":
        return attemptTerminalInsertion(text)
    case "com.adobe.Photoshop":
        return false // Graphics apps don't support text insertion
    default:
        return false
    }
}
```

### User Experience Enhancements
- **Visual Feedback**: Status indicator showing which method succeeded
- **Persistent Notifications**: For manual paste scenarios with action buttons
- **Application Learning**: Remember which methods work for specific apps

### Advantages
- Graceful degradation with multiple fallback options
- User education about insertion capabilities
- Maintains text availability in all scenarios

### Implementation Complexity
**High** - Requires extensive testing, notification system, and app-specific handling

---

## Solution 3: Smart Buffer System

### Implementation Strategy
Create a temporary holding system that retains transcribed text when insertion fails, with intelligent retry mechanisms.

### Technical Approach
```swift
class SmartTextBuffer {
    private var pendingTexts: [(text: String, timestamp: Date, retryCount: Int)] = []
    private let maxRetries = 3
    private let retryInterval: TimeInterval = 2.0
    
    func bufferText(_ text: String) {
        pendingTexts.append((text, Date(), 0))
        copyToClipboard(text)
        showBufferIndicator()
        scheduleRetry()
    }
    
    private func scheduleRetry() {
        Timer.scheduledTimer(withTimeInterval: retryInterval, repeats: false) { [weak self] _ in
            self?.attemptBufferedInsertions()
        }
    }
    
    private func attemptBufferedInsertions() {
        var successfulInsertions: [Int] = []
        
        for (index, var item) in pendingTexts.enumerated() {
            if validateCursorPosition() == .directInsertion {
                if attemptDirectInsertion(item.text) {
                    successfulInsertions.append(index)
                    logSuccess("Buffered text inserted: '\(item.text)'")
                    continue
                }
            }
            
            // Increment retry count
            item.retryCount += 1
            pendingTexts[index] = item
            
            // Remove if max retries reached or text is too old
            if item.retryCount >= maxRetries || Date().timeIntervalSince(item.timestamp) > 30 {
                logWarning("Giving up on buffered text: '\(item.text)'")
                successfulInsertions.append(index)
            }
        }
        
        // Remove processed items (in reverse order to maintain indices)
        for index in successfulInsertions.reversed() {
            pendingTexts.remove(at: index)
        }
        
        updateBufferIndicator()
        
        // Schedule next retry if items remain
        if !pendingTexts.isEmpty {
            scheduleRetry()
        }
    }
    
    private func showBufferIndicator() {
        // Show menu bar indicator with pending text count
        AppDelegate.shared.statusItem.button?.title = "🎤(\(pendingTexts.count))"
    }
}
```

### User Interface Elements
- **Buffer Indicator**: Menu bar icon showing pending text count
- **Buffer Management**: Menu option to view/clear buffered texts
- **Smart Notifications**: "Text inserted when you returned to document"

### Advantages
- Never loses transcribed text
- Automatic insertion when cursor becomes valid
- User awareness of pending content
- Configurable retry behavior

### Implementation Complexity
**Medium-High** - Requires timer management, UI updates, and state persistence

---

## Solution 4: Context-Aware Overlay System (Creative)

### Implementation Strategy
Create a floating overlay window that appears when direct insertion fails, showing transcribed text with smart positioning and contextual actions.

### Technical Approach
```swift
class ContextualOverlay: NSWindow {
    private var transcribedText: String = ""
    private var overlayTimer: Timer?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupOverlayAppearance()
    }
    
    private func setupOverlayAppearance() {
        level = .floating
        backgroundColor = NSColor.black.withAlphaComponent(0.8)
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
    }
    
    func showOverlay(with text: String, at cursorLocation: NSPoint) {
        transcribedText = text
        
        // Position overlay near cursor, but avoid screen edges
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        var overlayFrame = frame
        
        overlayFrame.origin.x = min(cursorLocation.x, screenFrame.maxX - frame.width - 20)
        overlayFrame.origin.y = max(cursorLocation.y - frame.height - 10, 20)
        
        setFrame(overlayFrame, display: true)
        
        // Create overlay content
        let contentView = OverlayContentView(text: text) { [weak self] action in
            self?.handleOverlayAction(action)
        }
        
        self.contentView = contentView
        makeKeyAndOrderFront(nil)
        
        // Auto-dismiss after 10 seconds
        overlayTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.hideOverlay()
        }
    }
    
    private func handleOverlayAction(_ action: OverlayAction) {
        switch action {
        case .paste:
            performPasteOperation()
        case .copy:
            copyToClipboard(transcribedText)
            showBriefSuccess("Copied to clipboard")
        case .dismiss:
            hideOverlay()
        case .edit:
            showTextEditingDialog()
        }
    }
}

class OverlayContentView: NSView {
    private let text: String
    private let actionHandler: (OverlayAction) -> Void
    
    init(text: String, actionHandler: @escaping (OverlayAction) -> Void) {
        self.text = text
        self.actionHandler = actionHandler
        super.init(frame: .zero)
        setupSubviews()
    }
    
    private func setupSubviews() {
        // Text display with smart truncation
        let textLabel = NSTextField(labelWithString: text.prefix(100) + (text.count > 100 ? "..." : ""))
        textLabel.textColor = .white
        textLabel.font = .systemFont(ofSize: 14)
        
        // Action buttons
        let pasteButton = NSButton(title: "Paste", target: self, action: #selector(pasteAction))
        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyAction))
        let editButton = NSButton(title: "Edit", target: self, action: #selector(editAction))
        let dismissButton = NSButton(title: "×", target: self, action: #selector(dismissAction))
        
        // Layout with auto-layout
        [textLabel, pasteButton, copyButton, editButton, dismissButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            pasteButton.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 8),
            pasteButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            
            copyButton.centerYAnchor.constraint(equalTo: pasteButton.centerYAnchor),
            copyButton.leadingAnchor.constraint(equalTo: pasteButton.trailingAnchor, constant: 8),
            
            editButton.centerYAnchor.constraint(equalTo: pasteButton.centerYAnchor),
            editButton.leadingAnchor.constraint(equalTo: copyButton.trailingAnchor, constant: 8),
            
            dismissButton.centerYAnchor.constraint(equalTo: pasteButton.centerYAnchor),
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            pasteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    @objc private func pasteAction() { actionHandler(.paste) }
    @objc private func copyAction() { actionHandler(.copy) }
    @objc private func editAction() { actionHandler(.edit) }
    @objc private func dismissAction() { actionHandler(.dismiss) }
}

enum OverlayAction {
    case paste, copy, dismiss, edit
}
```

### Advanced Features
- **Cursor Tracking**: Overlay repositions based on actual cursor location
- **Context Detection**: Different actions based on active application
- **Text Editing**: In-place editing before insertion
- **Gesture Support**: Swipe to dismiss, click-drag to reposition
- **Learning**: Remembers user preferences for different contexts

### User Experience Benefits
- **Visual Continuity**: Text never "disappears"
- **Immediate Action**: One-click paste/copy operations
- **Spatial Context**: Appears near intended insertion point
- **Progressive Disclosure**: Advanced options available when needed

### Advantages
- Unique, intuitive user experience
- Never loses transcribed text
- Provides immediate visual feedback
- Offers multiple interaction options
- Can work in any application context

### Implementation Complexity
**High** - Requires custom window management, cursor tracking, and extensive UI work

---

## Recommendation Matrix

| Solution | Implementation Effort | User Experience | Reliability | Innovation |
|----------|----------------------|-----------------|-------------|------------|
| Cursor Validation | Medium | Good | High | Low |
| Progressive Fallback | High | Excellent | Very High | Medium |
| Smart Buffer | Medium-High | Good | High | Medium |
| Context Overlay | High | Outstanding | High | Very High |

## Implementation Priority

1. **Phase 1**: Implement **Cursor Validation** as it provides immediate improvement with moderate effort
2. **Phase 2**: Add **Smart Buffer System** for comprehensive text retention
3. **Phase 3**: Consider **Context-Aware Overlay** for premium user experience
4. **Future**: **Progressive Fallback** as a comprehensive enterprise solution

Each solution addresses the core problem while offering different trade-offs between implementation complexity and user experience enhancement.