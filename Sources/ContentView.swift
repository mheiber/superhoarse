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
                
                KeyboardShortcutConfigView()
            }
        }
        .padding()
        .frame(width: 400, height: appState.hasAccessibilityPermission ? 420 : 500)
        .background(Color(.windowBackgroundColor))
    }
}

struct HeaderView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            Text("Superhoarse")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Press \(appState.getCurrentShortcutString()) to record")
                .font(.caption)
                .foregroundColor(.secondary)
                
            Text("Using \(appState.currentSpeechEngine.displayName)")
                .font(.caption2)
                .foregroundColor(appState.currentSpeechEngine == .parakeet ? .blue : .green)
                .padding(.top, 2)
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
                appState.transcriptionText = ""
            }
            .buttonStyle(.bordered)
        }
    }
}

struct KeyboardShortcutConfigView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("hotKeyModifier") private var hotKeyModifier: Int = 0
    @AppStorage("hotKeyCode") private var hotKeyCode: Int = 49
    
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
        VStack(spacing: 12) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
            }
            
            // Speech Engine Selection
            HStack {
                Text("Speech Engine:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Picker("Speech Engine", selection: $appState.currentSpeechEngine) {
                    ForEach(SpeechEngineType.allCases, id: \.self) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
                .onChange(of: appState.currentSpeechEngine) { newEngine in
                    appState.switchSpeechEngine(to: newEngine)
                }
            }
            
            Divider()
            
            // Keyboard Shortcut Section
            HStack {
                Text("Keyboard Shortcut")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(currentShortcutString)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Modifier:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Modifier", selection: $hotKeyModifier) {
                        ForEach(modifierOptions, id: \.value) { option in
                            Text(option.name).tag(option.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Key:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Key", selection: $hotKeyCode) {
                        ForEach(keyOptions, id: \.code) { option in
                            Text(option.name).tag(option.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
                
                VStack {
                    Spacer()
                    Button("Apply") {
                        NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
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
            
            WaveformVisualizerView(audioLevel: appState.currentAudioLevel)
            
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
    @State private var waveformBars: [Float] = Array(repeating: 0.02, count: 40)
    @State private var animationTimer: Timer?
    @State private var phase: Double = 0.0
    
    var body: some View {
        HStack(alignment: .center, spacing: 1) {
            ForEach(0..<waveformBars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.0, blue: 1.0),  // Magenta
                            Color(red: 0.8, green: 0.0, blue: 1.0),  // Purple-pink
                            Color(red: 0.4, green: 0.0, blue: 1.0),  // Deep purple
                            Color(red: 0.0, green: 0.8, blue: 1.0)   // Cyan
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: 4, height: max(3, CGFloat(waveformBars[index]) * 80))
                    .animation(.easeOut(duration: 0.08), value: waveformBars[index])
                    .shadow(color: Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.6), radius: 2)
            }
        }
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .shadow(color: Color(red: 0.4, green: 0.0, blue: 1.0).opacity(0.5), radius: 4)
        )
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
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updateWaveform(with: audioLevel)
        }
    }
    
    private func stopWaveformAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateWaveform(with level: Float) {
        phase += 0.3
        
        let baseLevel = max(0.02, level)
        let scaledLevel = pow(baseLevel, 0.7)
        
        for i in 0..<waveformBars.count {
            let position = Float(i) / Float(waveformBars.count - 1)
            let centerDistance = abs(position - 0.5) * 2.0
            let falloff = 1.0 - pow(centerDistance, 1.5)
            
            let waveOffset = sin(Double(i) * 0.8 + phase) * 0.15
            let heightMultiplier = scaledLevel * falloff + Float(waveOffset) * scaledLevel * 0.3
            
            let minHeight: Float = audioLevel < 0.01 ? 0.02 : 0.1
            waveformBars[i] = max(minHeight, min(1.0, heightMultiplier))
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