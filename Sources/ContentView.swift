import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Synthwave background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.0, blue: 0.2),
                    Color(red: 0.05, green: 0.0, blue: 0.15)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    if !appState.isInitialized {
                        InitializingView()
                    } else {
                        HeaderView()
                        
                        if !appState.hasAccessibilityPermission {
                            AccessibilityPermissionView()
                        }
                        
                        RecordingStatusView()
                        
                        KeyboardShortcutConfigView()
                        
                        Spacer(minLength: 20)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct InitializingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 1.0, green: 0.0, blue: 1.0)))
                .scaleEffect(1.5)
            
            Text("Initializing Whisper...")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.5),
                                    Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
    }
}

struct HeaderView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 8) {
            // Main title with neon effect
            Text("SUPERHOARSE")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.0, blue: 1.0),
                            Color(red: 0.8, green: 0.0, blue: 1.0),
                            Color(red: 0.0, green: 0.8, blue: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color(red: 1.0, green: 0.0, blue: 1.0), radius: 4)
                .shadow(color: Color(red: 1.0, green: 0.0, blue: 1.0), radius: 8)
            
            // Subtitle
            Text("AI-POWERED SPEECH RECOGNITION")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .tracking(2)
            
            // Shortcut instruction
            HStack(spacing: 6) {
                Text("PRESS")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                
                Text(appState.getCurrentShortcutString())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.6), lineWidth: 1)
                            )
                    )
                
                Text("TO RECORD")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 4)
                
            // Engine status
            Text("ENGINE: \(appState.currentSpeechEngine.displayName.uppercased())")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(appState.currentSpeechEngine == .parakeet ? 
                    Color(red: 0.8, green: 0.0, blue: 1.0) : 
                    Color(red: 0.0, green: 1.0, blue: 0.5))
                .padding(.top, 2)
        }
        .padding(.vertical, 12)
    }
}

struct RecordingStatusView: View {
    @EnvironmentObject var appState: AppState
    @State private var pulseAnimation: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(appState.isRecording ? 
                        Color(red: 1.0, green: 0.0, blue: 0.5) : 
                        Color.white.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .scaleEffect(appState.isRecording ? (pulseAnimation ? 1.3 : 1.0) : 1.0)
                    .shadow(color: appState.isRecording ? 
                        Color(red: 1.0, green: 0.0, blue: 0.5) : 
                        Color.white.opacity(0.5), 
                        radius: appState.isRecording ? 8 : 4)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseAnimation)
                    .onAppear {
                        if appState.isRecording {
                            pulseAnimation = true
                        }
                    }
                    .onChange(of: appState.isRecording) { isRecording in
                        pulseAnimation = isRecording
                    }
                
                if appState.isRecording {
                    Circle()
                        .stroke(Color(red: 1.0, green: 0.0, blue: 0.5).opacity(0.4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)
                        .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: pulseAnimation)
                }
            }
            
            // Status text
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.isRecording ? "RECORDING" : "READY")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(appState.isRecording ? 
                        Color(red: 1.0, green: 0.0, blue: 0.5) : 
                        Color(red: 0.0, green: 1.0, blue: 0.5))
                
                Text(appState.isRecording ? "Listening for speech..." : "Press hotkey to start")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: appState.isRecording ? [
                                    Color(red: 1.0, green: 0.0, blue: 0.5).opacity(0.6),
                                    Color(red: 1.0, green: 0.2, blue: 0.8).opacity(0.6)
                                ] : [
                                    Color(red: 0.0, green: 1.0, blue: 0.5).opacity(0.4),
                                    Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.4)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: appState.isRecording ? 
                    Color(red: 1.0, green: 0.0, blue: 0.5).opacity(0.3) : 
                    Color(red: 0.0, green: 1.0, blue: 0.5).opacity(0.2), 
                    radius: 8)
        )
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
    @State private var warningPulse: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Warning icon with animation
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.2))
                    .frame(width: 40, height: 40)
                    .scaleEffect(warningPulse ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: warningPulse)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.0))
                    .shadow(color: Color(red: 1.0, green: 0.5, blue: 0.0), radius: 3)
            }
            .onAppear {
                warningPulse = true
            }
            
            VStack(spacing: 8) {
                Text("ACCESSIBILITY PERMISSION REQUIRED")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.0))
                    .multilineTextAlignment(.center)
                
                Text("Text insertion requires accessibility permission.\nTranscriptions will still be copied to clipboard.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            // Grant permission button
            Button(action: {
                appState.requestAccessibilityPermissions()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("GRANT PERMISSION")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.5, blue: 0.0),
                                    Color(red: 1.0, green: 0.7, blue: 0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.6), radius: 8)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.6),
                                    Color(red: 1.0, green: 0.7, blue: 0.2).opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.3), radius: 12)
        )
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
        VStack(spacing: 16) {
            // Speech Engine Section
            VStack(spacing: 12) {
                HStack {
                    Text("SPEECH ENGINE")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                    
                    Spacer()
                    
                    Text("ENGINE: \(appState.currentSpeechEngine.displayName.uppercased())")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(appState.currentSpeechEngine == .parakeet ? 
                            Color(red: 0.8, green: 0.0, blue: 1.0) : 
                            Color(red: 0.0, green: 1.0, blue: 0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(appState.currentSpeechEngine == .parakeet ? 
                                            Color(red: 0.8, green: 0.0, blue: 1.0).opacity(0.6) : 
                                            Color(red: 0.0, green: 1.0, blue: 0.5).opacity(0.6), lineWidth: 1)
                                )
                        )
                }
                
                HStack {
                    Text("RECOGNITION ENGINE:")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Menu {
                        ForEach(SpeechEngineType.allCases, id: \.self) { engine in
                            Button(action: {
                                appState.currentSpeechEngine = engine
                                appState.switchSpeechEngine(to: engine)
                            }) {
                                HStack {
                                    Text(engine.displayName.uppercased())
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    
                                    if appState.currentSpeechEngine == engine {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.5))
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(appState.currentSpeechEngine.displayName.uppercased())
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.6), lineWidth: 1)
                                )
                        )
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .frame(width: 200)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.4),
                                        Color(red: 0.4, green: 0.0, blue: 1.0).opacity(0.4)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.2), radius: 8)
            )
            
            // Keyboard Shortcut Section
            VStack(spacing: 12) {
                HStack {
                    Text("HOTKEY CONFIGURATION")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 1.0, green: 0.0, blue: 1.0))
                    
                    Spacer()
                    
                    Text(currentShortcutString)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.6), lineWidth: 1)
                                )
                        )
                }
                
                HStack(spacing: 20) {
                    // Modifier picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MODIFIER KEYS:")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Menu {
                            ForEach(modifierOptions, id: \.value) { option in
                                Button(action: {
                                    hotKeyModifier = option.value
                                    NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
                                }) {
                                    HStack {
                                        Text(option.name)
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        
                                        if hotKeyModifier == option.value {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color(red: 1.0, green: 0.0, blue: 1.0))
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(modifierOptions.first { $0.value == hotKeyModifier }?.name ?? "⌘⇧")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(red: 1.0, green: 0.0, blue: 1.0))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black.opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.6), lineWidth: 1)
                                    )
                            )
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                        .frame(width: 200)
                    }
                    
                    // Key picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TRIGGER KEY:")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Menu {
                            ForEach(keyOptions, id: \.code) { option in
                                Button(action: {
                                    hotKeyCode = option.code
                                    NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
                                }) {
                                    HStack {
                                        Text(option.name)
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        
                                        if hotKeyCode == option.code {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color(red: 1.0, green: 0.0, blue: 1.0))
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(keyOptions.first { $0.code == hotKeyCode }?.name ?? "Space")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(red: 1.0, green: 0.0, blue: 1.0))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black.opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.6), lineWidth: 1)
                                    )
                            )
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                        .frame(width: 140)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.4),
                                        Color(red: 0.8, green: 0.0, blue: 1.0).opacity(0.4)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.2), radius: 8)
            )
        }
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
                Spacer()
                
                Button(action: {
                    appState.hideListeningIndicator()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            WaveformVisualizerView(audioLevel: appState.currentAudioLevel)
            
            HStack {
                Text("Press \(appState.getCurrentShortcutString()) to stop")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Text("ESC to close")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
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
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<waveformBars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.8),  // Magenta
                            Color(red: 0.8, green: 0.0, blue: 1.0).opacity(0.8),  // Purple-pink
                            Color(red: 0.4, green: 0.0, blue: 1.0).opacity(0.8),  // Deep purple
                            Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.8)   // Cyan
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: 6, height: max(4, CGFloat(waveformBars[index]) * 120))
                    .animation(.easeOut(duration: 0.08), value: waveformBars[index])
                    .shadow(color: Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.8), radius: 3)
            }
        }
        .frame(height: 120)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.15),
                            Color(red: 0.1, green: 0.0, blue: 0.2).opacity(0.25)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.5),
                                    Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color(red: 0.4, green: 0.0, blue: 1.0).opacity(0.6), radius: 8)
                .shadow(color: Color.black.opacity(0.3), radius: 12)
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