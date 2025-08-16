import SwiftUI
import AppKit
import Combine
import os.log

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
    private var settingsWindow: NSWindow?
    private var listeningIndicatorWindow: NSWindow?
    private var appState: AppState?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.superhoarse.lite", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // COVERAGE_EXCLUDE_START - App delegate lifecycle methods require full app launch to test
        // Set activation policy to .accessory to run as a menu bar app (no Dock icon).
        NSApp.setActivationPolicy(.accessory)
        
        setupMenuBar()
        
        // Initialize the shared AppState and set up listeners.
        appState = AppState.shared
        setupAppStateListeners()
        
        // Open settings on launch  
        openSettings()
        
        logger.info("Superhoarse launched successfully as a menu bar app.")
        // COVERAGE_EXCLUDE_END
    }
    
    // COVERAGE_EXCLUDE_START - App delegate lifecycle methods require full app to test
    // Keep the app running even when the settings window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
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
        
        // Create menu items with synthwave styling
        let settingsItem = NSMenuItem(title: "OPEN SETTINGS", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.attributedTitle = NSAttributedString(
            string: "⚡ OPEN SETTINGS",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: NSColor.systemPurple
            ]
        )
        
        let separatorItem = NSMenuItem.separator()
        
        let quitItem = NSMenuItem(title: "QUIT SUPERHOARSE", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.attributedTitle = NSAttributedString(
            string: "QUIT SUPERHOARSE",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: NSColor.systemRed
            ]
        )
        
        menu.addItem(settingsItem)
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
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.minSize = NSSize(width: 600, height: 500)
            settingsWindow?.maxSize = NSSize(width: 1000, height: 1200)
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
    }
    
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
    // COVERAGE_EXCLUDE_END
}



// COVERAGE_EXCLUDE_START - Main entry point cannot be unit tested as it starts the app
// This is the SwiftUI app lifecycle entry point and requires a running app to test
// Main entry point for the SwiftUI application.
SuperhoarseApp.main()
// COVERAGE_EXCLUDE_END
