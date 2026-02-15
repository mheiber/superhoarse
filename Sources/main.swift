import SwiftUI
import AppKit
import Combine
import os.log
import ApplicationServices

// Using Settings {} defines the app as a menu bar application.
// This ensures a single, consistent process, fixing the accessibility permission issue.
struct SuperhoarseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        Settings {
            // The settings view is now managed by the AppDelegate
            // to ensure it runs in the context of the main app process.
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsMenuItem: NSMenuItem?
    private var settingsWindow: NSWindow?
    private var listeningIndicatorWindow: NSWindow?
    private var pasteNotificationWindow: NSWindow?
    private var accessibilityNotificationWindow: NSWindow?
    private var appState: AppState?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.superhoarse.lite", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // COVERAGE_EXCLUDE_START - App delegate lifecycle methods require full app launch to test
        // Set activation policy based on user preference (default: show in dock)
        let showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
        let activationPolicy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        NSApp.setActivationPolicy(activationPolicy)
        
        
        setupMenuBar()
        
        // Initialize the shared AppState and set up listeners.
        appState = AppState.shared
        setupAppStateListeners()
        
        // Check accessibility permissions directly to avoid timing issues
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let hasPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        // Set initial menu item text based on current permission state
        updateMenuBarIcon(hasPermission: hasPermission)
        
        // Open settings on launch only if accessibility permissions are not granted
        if !hasPermission {
            openSettings()
        }
        
        logger.info("Superhoarse launched successfully as a menu bar app.")
        // COVERAGE_EXCLUDE_END
    }
    
    // COVERAGE_EXCLUDE_START - App delegate lifecycle methods require full app to test
    // Keep the app running even when the settings window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return false
    }
    
    // Handle dock icon clicks when app is visible in dock
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When dock icon is clicked, open settings window
        openSettings()
        return false
    }
    
    // Prevent new instances when app is already running
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Instead of creating a new file, show settings
        openSettings()
        return false
    }
    // COVERAGE_EXCLUDE_END
    
    // COVERAGE_EXCLUDE_START - Menu bar and UI setup requires running macOS app to test
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // Create a custom icon with synthwave colors
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .bold)
            if let micImage = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Superhoarse")?.withSymbolConfiguration(config) {
                // Tint the icon with a magenta color
                micImage.isTemplate = false
                button.image = micImage
            }
            button.toolTip = "🎙️ SUPERHOARSE - AI Speech Recognition"
        }
        
        let menu = NSMenu()
        
        // Style the menu with dark background
        menu.appearance = NSAppearance(named: .darkAqua)
        
        // Create menu items with synthwave styling - will be updated based on permissions
        settingsMenuItem = NSMenuItem(title: "OPEN SETTINGS", action: #selector(openSettings), keyEquivalent: "")
        // Initial text will be set by updateMenuBarIcon
        
        let separatorItem = NSMenuItem.separator()
        
        let quitItem = NSMenuItem(title: "QUIT SUPERHOARSE", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.attributedTitle = NSAttributedString(
            string: "QUIT SUPERHOARSE",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: NSColor.systemRed
            ]
        )
        
        menu.addItem(settingsMenuItem!)
        menu.addItem(separatorItem)
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    // COVERAGE_EXCLUDE_END
    
    // COVERAGE_EXCLUDE_START - Window management requires running macOS app with UI to test
    @MainActor
    @objc private func openSettings() {
        if settingsWindow == nil {
            // The main ContentView now serves as the settings view.
            let contentView = ContentView().environmentObject(appState!)
            let hostingController = NSHostingController(rootView: contentView)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 1400),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.minSize = NSSize(width: 600, height: 800)
            settingsWindow?.maxSize = NSSize(width: 1000, height: 1600)
            settingsWindow?.title = "Superhoarse Settings"
            settingsWindow?.contentViewController = hostingController
            settingsWindow?.center()
            // Reuse the window instance instead of releasing it on close.
            settingsWindow?.isReleasedWhenClosed = false
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logger.info("Settings window opened.")
    }
    // COVERAGE_EXCLUDE_END
    
    @MainActor
    private func setupAppStateListeners() {
        guard let appState = appState else {
            logger.error("AppState not initialized.")
            return
        }
        
        appState.$showListeningIndicator
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                self?.toggleListeningIndicator(show)
            }
            .store(in: &cancellables)
        
        appState.$showPasteNotification
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                self?.togglePasteNotification(show)
            }
            .store(in: &cancellables)

        appState.$showAccessibilityNotification
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                self?.toggleAccessibilityNotification(show)
            }
            .store(in: &cancellables)

        appState.$shouldOpenSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldOpen in
                if shouldOpen {
                    self?.appState?.shouldOpenSettings = false
                    self?.openSettings()
                }
            }
            .store(in: &cancellables)
        
        appState.$hasAccessibilityPermission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasPermission in
                self?.updateMenuBarIcon(hasPermission: hasPermission)
            }
            .store(in: &cancellables)
    }
    
    // COVERAGE_EXCLUDE_START - Menu bar icon updates require running macOS app to test
    private func updateMenuBarIcon(hasPermission: Bool) {
        // Update settings menu item based on permission status
        if hasPermission {
            // Update settings menu item with lightning bolt
            settingsMenuItem?.attributedTitle = NSAttributedString(
                string: "⚡ OPEN SETTINGS",
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                    .foregroundColor: NSColor.systemPurple
                ]
            )
        } else {
            // Update settings menu item with caution icon
            settingsMenuItem?.attributedTitle = NSAttributedString(
                string: "⚠️ OPEN SETTINGS",
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                    .foregroundColor: NSColor.systemOrange
                ]
            )
        }
        
        logger.info("Settings menu item updated - hasPermission: \(hasPermission)")
    }
    // COVERAGE_EXCLUDE_END
    
    // COVERAGE_EXCLUDE_START - UI indicator management requires running app with windows
    private func toggleListeningIndicator(_ show: Bool) {
        if show {
            showListeningIndicator()
        } else {
            hideListeningIndicator()
        }
    }
    
    private func showListeningIndicator() {
        guard let appState = appState else { return }
        
        if listeningIndicatorWindow == nil {
            // Assuming ListeningIndicatorView exists.
            let indicatorView = ListeningIndicatorView().environmentObject(appState)
            let hostingController = NSHostingController(rootView: indicatorView)
            
            listeningIndicatorWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 120),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            listeningIndicatorWindow?.contentViewController = hostingController
            listeningIndicatorWindow?.isOpaque = false
            listeningIndicatorWindow?.backgroundColor = .clear
            listeningIndicatorWindow?.level = .floating
            listeningIndicatorWindow?.isMovableByWindowBackground = true
            listeningIndicatorWindow?.isReleasedWhenClosed = false
            
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowSize = listeningIndicatorWindow?.frame.size ?? .zero
                let x = screenFrame.midX - windowSize.width / 2
                let y = screenFrame.maxY - windowSize.height - 20
                listeningIndicatorWindow?.setFrameOrigin(CGPoint(x: x, y: y))
            }
        }
        
        listeningIndicatorWindow?.makeKeyAndOrderFront(nil)
        logger.info("Listening indicator shown.")
    }
    
    private func hideListeningIndicator() {
        listeningIndicatorWindow?.orderOut(nil)
        logger.info("Listening indicator hidden.")
    }
    
    @MainActor
    private func togglePasteNotification(_ show: Bool) {
        if show {
            showPasteNotification()
        } else {
            hidePasteNotification()
        }
    }
    
    @MainActor
    private func showPasteNotification() {
        guard let appState = appState else { return }
        
        // Don't show popup if settings window is focused
        if let settingsWindow = settingsWindow, settingsWindow.isKeyWindow {
            logger.info("Settings window is focused, not showing paste notification")
            return
        }
        
        // Always recreate the window with fresh content
        let notificationView = PasteNotificationView(transcribedText: appState.transcriptionText)
            .environmentObject(appState)
        let hostingController = NSHostingController(rootView: notificationView)
        
        pasteNotificationWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 320),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        pasteNotificationWindow?.contentViewController = hostingController
        pasteNotificationWindow?.isOpaque = false
        pasteNotificationWindow?.backgroundColor = .clear
        pasteNotificationWindow?.level = .floating
        pasteNotificationWindow?.isMovableByWindowBackground = true
        pasteNotificationWindow?.isReleasedWhenClosed = false
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowSize = pasteNotificationWindow?.frame.size ?? .zero
            let x = screenFrame.midX - windowSize.width / 2
            let y = screenFrame.midY + 50
            pasteNotificationWindow?.setFrameOrigin(CGPoint(x: x, y: y))
        }
        
        pasteNotificationWindow?.makeKeyAndOrderFront(nil)
        logger.info("Paste notification shown with text: '\(appState.transcriptionText)'")
    }
    
    private func hidePasteNotification() {
        pasteNotificationWindow?.orderOut(nil)
        logger.info("Paste notification hidden.")
    }

    @MainActor
    private func toggleAccessibilityNotification(_ show: Bool) {
        if show {
            showAccessibilityNotification()
        } else {
            hideAccessibilityNotification()
        }
    }

    @MainActor
    private func showAccessibilityNotification() {
        guard let appState = appState else { return }

        // Don't show popup if settings window is focused
        if let settingsWindow = settingsWindow, settingsWindow.isKeyWindow {
            logger.info("Settings window is focused, not showing accessibility notification")
            return
        }

        let notificationView = AccessibilityNotificationView()
            .environmentObject(appState)
        let hostingController = NSHostingController(rootView: notificationView)

        accessibilityNotificationWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 320),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        accessibilityNotificationWindow?.contentViewController = hostingController
        accessibilityNotificationWindow?.isOpaque = false
        accessibilityNotificationWindow?.backgroundColor = .clear
        accessibilityNotificationWindow?.level = .floating
        accessibilityNotificationWindow?.isMovableByWindowBackground = true
        accessibilityNotificationWindow?.isReleasedWhenClosed = false

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowSize = accessibilityNotificationWindow?.frame.size ?? .zero
            let x = screenFrame.midX - windowSize.width / 2
            let y = screenFrame.midY + 50
            accessibilityNotificationWindow?.setFrameOrigin(CGPoint(x: x, y: y))
        }

        accessibilityNotificationWindow?.makeKeyAndOrderFront(nil)
        logger.info("Accessibility notification shown")
    }

    private func hideAccessibilityNotification() {
        accessibilityNotificationWindow?.orderOut(nil)
        logger.info("Accessibility notification hidden.")
    }
    // COVERAGE_EXCLUDE_END
}



// COVERAGE_EXCLUDE_START - Main entry point cannot be unit tested as it starts the app
// This is the SwiftUI app lifecycle entry point and requires a running app to test
// Main entry point for the SwiftUI application.
SuperhoarseApp.main()
// COVERAGE_EXCLUDE_END
