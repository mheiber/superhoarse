import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            if !appState.isInitialized {
                ProgressView("Initializing Whisper...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                HeaderView()
                
                if !appState.hasAccessibilityPermission {
                    AccessibilityPermissionView()
                }
                
                RecordingStatusView()
                
                TranscriptionView()
                
                ControlsView()
            }
        }
        .padding()
        .frame(width: 400, height: appState.hasAccessibilityPermission ? 300 : 380)
        .background(Color(.windowBackgroundColor))
    }
}

struct HeaderView: View {
    var body: some View {
        VStack {
            Text("Superhoarse")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Press ⌘⇧Space to record")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct RecordingStatusView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            Circle()
                .fill(appState.isRecording ? Color.red : Color.gray)
                .frame(width: 12, height: 12)
                .scaleEffect(appState.isRecording ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: appState.isRecording)
            
            Text(appState.isRecording ? "Recording..." : "Ready")
                .font(.headline)
                .foregroundColor(appState.isRecording ? .red : .primary)
        }
    }
}

struct TranscriptionView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            Text(appState.transcriptionText.isEmpty ? "Your transcription will appear here" : appState.transcriptionText)
                .font(.body)
                .foregroundColor(appState.transcriptionText.isEmpty ? .secondary : .primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 100)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct AccessibilityPermissionView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text("Accessibility Permission Required")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text("Text insertion requires accessibility permission. Transcriptions will still be copied to clipboard.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Grant Permission") {
                appState.requestAccessibilityPermissions()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ControlsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            Button(action: {
                appState.toggleRecording()
            }) {
                Label(appState.isRecording ? "Stop" : "Record", 
                      systemImage: appState.isRecording ? "stop.circle" : "mic.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!appState.isInitialized)
            
            Spacer()
            
            Button("Clear") {
                // Clear transcription
            }
            .buttonStyle(.bordered)
            
            Button("Settings") {
                // Open settings
            }
            .buttonStyle(.bordered)
        }
    }
}

struct SettingsView: View {
    @AppStorage("hotKeyModifier") private var hotKeyModifier: Int = 0
    @AppStorage("hotKeyCode") private var hotKeyCode: Int = 49 // Space key
    
    private let modifierOptions = [
        (name: "⌘⇧ (Cmd+Shift)", value: 0),
        (name: "⌘⌥ (Cmd+Option)", value: 1),
        (name: "⌘⌃ (Cmd+Control)", value: 2),
        (name: "⌥⇧ (Option+Shift)", value: 3)
    ]
    
    private let keyOptions = [
        (name: "Space", code: 49),
        (name: "R", code: 15),
        (name: "T", code: 17),
        (name: "M", code: 46),
        (name: "V", code: 9)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Keyboard Shortcut Configuration")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Modifier Keys:")
                    .font(.headline)
                
                Picker("Modifier", selection: $hotKeyModifier) {
                    ForEach(modifierOptions, id: \.value) { option in
                        Text(option.name).tag(option.value)
                    }
                }
                .pickerStyle(.menu)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Key:")
                    .font(.headline)
                
                Picker("Key", selection: $hotKeyCode) {
                    ForEach(keyOptions, id: \.code) { option in
                        Text(option.name).tag(option.code)
                    }
                }
                .pickerStyle(.menu)
            }
            
            HStack {
                Text("Current shortcut:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(currentShortcutString)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Apply Changes") {
                    NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
    
    private var currentShortcutString: String {
        let modifierName = modifierOptions.first { $0.value == hotKeyModifier }?.name ?? "⌘⇧"
        let keyName = keyOptions.first { $0.code == hotKeyCode }?.name ?? "Space"
        return "\(modifierName.components(separatedBy: " ").first ?? "⌘⇧") + \(keyName)"
    }
}

struct ListeningIndicatorView: View {
    @EnvironmentObject var appState: AppState
    @State private var waveformData: [Float] = Array(repeating: 0.0, count: 20)
    @State private var animationPhase = 0.0
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Listening...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    appState.hideListeningIndicator()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            WaveformVisualizerView(audioLevel: appState.audioRecorder?.currentAudioLevel ?? 0.0)
            
            HStack {
                Text("Press \(appState.getCurrentShortcutString()) to stop")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("ESC to close")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .shadow(radius: 8)
        )
        .background(
            KeyEventHandlingView(onEscape: {
                appState.hideListeningIndicator()
            })
        )
        .onAppear {
            // Auto-focus the window to receive key events
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(NSApp.keyWindow?.contentView)
            }
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.showListeningIndicator)
    }
}

struct WaveformVisualizerView: View {
    let audioLevel: Float
    @State private var waveformBars: [Float] = Array(repeating: 0.1, count: 24)
    @State private var animationTimer: Timer?
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<waveformBars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.green, .yellow, .red]),
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: 3, height: max(2, CGFloat(waveformBars[index]) * 40))
                    .animation(.easeInOut(duration: 0.1), value: waveformBars[index])
            }
        }
        .frame(height: 40)
        .onAppear {
            startWaveformAnimation()
        }
        .onDisappear {
            stopWaveformAnimation()
        }
        .onChange(of: audioLevel) { newLevel in
            updateWaveform(with: newLevel)
        }
    }
    
    private func startWaveformAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateWaveform(with: audioLevel)
        }
    }
    
    private func stopWaveformAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateWaveform(with level: Float) {
        let currentLevel = max(0.1, level)
        
        for i in 0..<waveformBars.count {
            let baseHeight = currentLevel * (0.3 + Float.random(in: 0...0.7))
            let variation = Float.random(in: -0.1...0.1)
            waveformBars[i] = min(1.0, max(0.1, baseHeight + variation))
        }
    }
}

struct KeyEventHandlingView: NSViewRepresentable {
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onEscape = onEscape
        return view
    }
    
    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onEscape = onEscape
    }
}

class KeyCaptureView: NSView {
    var onEscape: (() -> Void)?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.window?.makeFirstResponder(self)
    }
}

extension Notification.Name {
    static let hotKeyChanged = Notification.Name("hotKeyChanged")
}

// Preview disabled due to macro compatibility issues
// #Preview {
//     ContentView()
//         .environmentObject(AppState())
// }