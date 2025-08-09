import SwiftUI
import AppKit
import Combine

struct SuperWhisperLiteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup("SuperWhisper Lite") {
            ContentView()
                .environmentObject(AppState.shared)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var listeningIndicatorWindow: NSWindow?
    private var appState: AppState?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show in dock and menu bar
        NSApp.setActivationPolicy(.regular)
        setupMenuBar()
        
        // Initialize AppState early to ensure hotkeys and recording work
        _ = AppState.shared  // Force initialization
        setupAppState()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return false
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "SuperWhisper Lite")
            button.toolTip = "SuperWhisper Lite"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.contentViewController = hostingController
            settingsWindow?.title = "SuperWhisper Lite Settings"
            settingsWindow?.center()
            
            // Ensure window is retained and prevent auto-closing
            settingsWindow?.isReleasedWhenClosed = false
        }
        
        guard let window = settingsWindow else {
            print("Failed to create settings window")
            return
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupAppState() {
        // Use the shared AppState instance
        appState = AppState.shared
        
        // Monitor for recording state changes
        appState?.$showListeningIndicator
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showIndicator in
                if showIndicator {
                    self?.showListeningIndicator()
                } else {
                    self?.hideListeningIndicator()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func showListeningIndicator() {
        guard let appState = appState else { return }
        
        if listeningIndicatorWindow == nil {
            let indicatorView = ListeningIndicatorView()
                .environmentObject(appState)
            
            let hostingController = NSHostingController(rootView: indicatorView)
            
            listeningIndicatorWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 120),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            listeningIndicatorWindow?.contentViewController = hostingController
            listeningIndicatorWindow?.isOpaque = false
            listeningIndicatorWindow?.backgroundColor = NSColor.clear
            listeningIndicatorWindow?.level = .floating
            listeningIndicatorWindow?.isMovableByWindowBackground = true
            listeningIndicatorWindow?.isReleasedWhenClosed = false
            
            // Position at top center of screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowSize = listeningIndicatorWindow?.frame.size ?? CGSize(width: 400, height: 120)
                let x = screenFrame.midX - windowSize.width / 2
                let y = screenFrame.maxY - windowSize.height - 20
                listeningIndicatorWindow?.setFrameOrigin(CGPoint(x: x, y: y))
            }
        }
        
        listeningIndicatorWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func hideListeningIndicator() {
        listeningIndicatorWindow?.orderOut(nil)
    }
}

// Main entry point
SuperWhisperLiteApp.main()