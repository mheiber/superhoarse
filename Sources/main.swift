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
    private let logger = Logger(subsystem: "com.superwhisper.lite", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to .accessory to run as a menu bar app (no Dock icon).
        NSApp.setActivationPolicy(.accessory)
        
        setupMenuBar()
        
        // Initialize the shared AppState and set up listeners.
        appState = AppState.shared
        setupAppStateListeners()
        
        // Open settings on launch  
        openSettings()
        
        logger.info("Superhoarse launched successfully as a menu bar app.")
    }
    
    // Keep the app running even when the settings window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return false
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "Superhoarse")
            button.toolTip = "Superhoarse"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Superhoarse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @MainActor
    @objc private func openSettings() {
        if settingsWindow == nil {
            // The main ContentView now serves as the settings view.
            let contentView = ContentView().environmentObject(appState!)
            let hostingController = NSHostingController(rootView: contentView)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
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
}



// Main entry point for the SwiftUI application.
SuperhoarseApp.main()
