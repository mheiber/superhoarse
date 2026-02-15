// COVERAGE_EXCLUDE_START - SwiftUI Views require UI testing framework, not unit tests
// SwiftUI views are declarative and best tested through UI automation tests
// Unit testing SwiftUI views requires complex mocking of the entire SwiftUI framework
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
                        
                        AppPreferencesView()
                        
                        KeyboardShortcutConfigView()
                        
                        Spacer(minLength: 20)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .frame(minWidth: 600)
    }
}

struct InitializingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 1.0, green: 0.0, blue: 1.0)))
                .scaleEffect(1.5)
            
            Text("Initializing Parakeet...")
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
            Text("AI-POWERED DICTATION")
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
                
                Text("AND START TALKING")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 12)
    }
}

struct RecordingStatusView: View {
    @EnvironmentObject var appState: AppState
    @State private var pulseAnimation: Bool = false
    @State private var showCopiedFeedback: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Main status section
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
                    Text(appState.isRecording ? "LISTENING" : "READY")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(appState.isRecording ? 
                            Color(red: 1.0, green: 0.0, blue: 0.5) : 
                            Color(red: 0.0, green: 1.0, blue: 0.5))
                    
                    Text(appState.isRecording ? "When you're done talking, press \(appState.getCurrentShortcutString()) to stop" : "Press \(appState.getCurrentShortcutString()) and start talking")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
            
            // Live transcription display when not recording but text is available
            if !appState.isRecording && !appState.transcriptionText.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("LAST TRANSCRIPTION:")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1)

                        Spacer()

                        if appState.copyToClipboard {
                            Text("COPIED TO CLIPBOARD")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.5))
                                .tracking(0.5)
                        }

                        // Copy to clipboard button
                        Button(action: {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(appState.transcriptionText, forType: .string)
                            showCopiedFeedback = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopiedFeedback = false
                            }
                        }) {
                            Image(systemName: showCopiedFeedback ? "checkmark.circle.fill" : "doc.on.clipboard")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(showCopiedFeedback ?
                                    Color(red: 0.0, green: 1.0, blue: 0.5) :
                                    .white.opacity(0.5))
                                .animation(.easeInOut(duration: 0.2), value: showCopiedFeedback)
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")
                    }
                    
                    ScrollView {
                        SelectableTextView(text: appState.transcriptionText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.0, green: 1.0, blue: 0.5).opacity(0.3),
                                                Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.3)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .padding(.top, 4)
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
                
                Text("The app won't be able to insert text until permissions are granted.\nTranscriptions will still be copied to clipboard.")
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
    @AppStorage("hotKeyCodePTT") private var hotKeyCodePTT: Int = 0  // 0 = use same as hotKeyCode
    @AppStorage("hotKeyModifierPTT") private var hotKeyModifierPTT: Int = -1  // -1 = use same as hotKeyModifier
    @State private var showToggleHelp = false
    @State private var showPTTHelp = false
    
    
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
                        .foregroundColor(Color(red: 0.8, green: 0.0, blue: 1.0))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(red: 0.8, green: 0.0, blue: 1.0).opacity(0.6), lineWidth: 1)
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
                }
                
                // Row 1: Trigger Key (modifier + key)
                HStack {
                    Text("TRIGGER KEY:")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showToggleHelp.toggle()
                            if showToggleHelp { showPTTHelp = false }
                        }
                    }) {
                        Text("(?)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(showToggleHelp ? Color(red: 0.0, green: 0.8, blue: 1.0) : .white.opacity(0.4))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // Toggle modifier dropdown
                    Menu {
                        ForEach(HotkeyConfiguration.modifierOptions, id: \.value) { option in
                            Button(action: {
                                hotKeyModifier = option.value
                                NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
                            }) {
                                HStack {
                                    Text(option.name)
                                    if hotKeyModifier == option.value {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(HotkeyConfiguration.modifierOptions.first { $0.value == hotKeyModifier }?.symbol ?? "⌥")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 1.0, green: 0.0, blue: 1.0))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
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
                    .fixedSize()

                    Text("+")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))

                    // Toggle key dropdown
                    Menu {
                        ForEach(HotkeyConfiguration.keyOptions, id: \.code) { option in
                            Button(action: {
                                hotKeyCode = option.code
                                NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
                            }) {
                                HStack {
                                    Text(option.name)
                                    if hotKeyCode == option.code {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(HotkeyConfiguration.keyOptions.first { $0.code == hotKeyCode }?.name ?? "Space")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 1.0, green: 0.0, blue: 1.0))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
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
                    .fixedSize()
                }

                // Inline help for TRIGGER KEY
                if showToggleHelp {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tap \(appState.getCurrentShortcutString()) to start recording.")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                            Text("Tap again to stop and transcribe.")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.0, green: 0.1, blue: 0.15).opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.3), lineWidth: 1)
                            )
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Row 2: Push-to-Talk Key (modifier + key)
                HStack {
                    Text("PUSH-TO-TALK KEY:")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPTTHelp.toggle()
                            if showPTTHelp { showToggleHelp = false }
                        }
                    }) {
                        Text("(?)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(showPTTHelp ? Color(red: 0.0, green: 0.8, blue: 1.0) : .white.opacity(0.4))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // PTT modifier dropdown
                    Menu {
                        ForEach(HotkeyConfiguration.modifierOptions, id: \.value) { option in
                            Button(action: {
                                hotKeyModifierPTT = option.value
                                NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
                            }) {
                                HStack {
                                    Text(option.name)
                                    if effectivePTTModifier == option.value {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(HotkeyConfiguration.modifierOptions.first { $0.value == effectivePTTModifier }?.symbol ?? "⌥")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 1.0, green: 0.0, blue: 1.0))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
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
                    .fixedSize()

                    Text("+")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))

                    // PTT key dropdown
                    Menu {
                        ForEach(HotkeyConfiguration.keyOptions, id: \.code) { option in
                            Button(action: {
                                hotKeyCodePTT = option.code
                                NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
                            }) {
                                HStack {
                                    Text(option.name)
                                    if effectivePTTKeyCode == option.code {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(HotkeyConfiguration.keyOptions.first { $0.code == effectivePTTKeyCode }?.name ?? "Space")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 1.0, green: 0.0, blue: 1.0))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
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
                    .fixedSize()
                }

                // Inline help for TRIGGER PUSH-TO-TALK
                if showPTTHelp {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hold \(appState.getCurrentPTTShortcutString()) while speaking.")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                            Text("Release to stop and transcribe.")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.0, green: 0.1, blue: 0.15).opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.3), lineWidth: 1)
                            )
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
    
    private var effectivePTTKeyCode: Int {
        return hotKeyCodePTT > 0 ? hotKeyCodePTT : hotKeyCode
    }

    private var effectivePTTModifier: Int {
        return hotKeyModifierPTT >= 0 ? hotKeyModifierPTT : hotKeyModifier
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
                // ESC instruction only shown in toggle mode.
                // During hold mode, the user's hand is on the hotkey and can't reach ESC.
                if appState.recordingIsToggleMode {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ESC to cancel")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.7))
                    )
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    // During hold: "Release ⌘⇧Space to stop"
                    // During toggle: "⌘⇧Space to stop"
                    if appState.recordingIsToggleMode {
                        Text("\(appState.getCurrentShortcutString()) to stop")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Text("Release \(appState.getCurrentPTTShortcutString()) to stop")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .shadow(radius: 8)
        )
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
                            Color(red: 0.1, green: 0.0, blue: 0.2).opacity(0.8)
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

struct SelectableTextView: View {
    let text: String
    @State private var displayText: String = ""
    
    var body: some View {
        TextEditor(text: $displayText)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundColor(Color(red: 0.8, green: 0.8, blue: 1.0))
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                displayText = text
            }
            .onChange(of: text) { newValue in
                displayText = newValue
            }
            .onChange(of: displayText) { newValue in
                // Prevent editing by reverting any changes back to original text
                if newValue != text {
                    displayText = text
                }
            }
    }
}


struct AppPreferencesView: View {
    @AppStorage("launchAtStartup") private var launchAtStartup: Bool = false
    @AppStorage("showInDock") private var showInDock: Bool = true
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            // App Preferences Section Header
            HStack {
                Text("APP PREFERENCES")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.5))
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Launch at Startup Setting
                HStack {
                    Text("LAUNCH AT STARTUP:")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Toggle("", isOn: $launchAtStartup)
                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0, green: 1.0, blue: 0.5)))
                        .onChange(of: launchAtStartup) { newValue in
                            updateLaunchAtStartup(enabled: newValue)
                        }
                }
                
                // Show in Dock Setting
                HStack {
                    Text("SHOW IN DOCK:")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Toggle("", isOn: $showInDock)
                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0, green: 1.0, blue: 0.5)))
                        .onChange(of: showInDock) { newValue in
                            updateDockVisibility(showInDock: newValue)
                        }
                }

                // Copy to Clipboard Setting
                HStack {
                    Text("COPY TO CLIPBOARD:")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Toggle("", isOn: $appState.copyToClipboard)
                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0, green: 1.0, blue: 0.5)))
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
                                    Color(red: 0.0, green: 1.0, blue: 0.5).opacity(0.4),
                                    Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.4)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color(red: 0.0, green: 1.0, blue: 0.5).opacity(0.2), radius: 8)
        )
    }
    
    private func updateLaunchAtStartup(enabled: Bool) {
        // For now, store the preference and show instructions to user
        // A future version could implement ServiceManagement framework
        UserDefaults.standard.set(enabled, forKey: "launchAtStartup")
        
        // Show user instructions for manual setup if needed
        if enabled {
            print("Launch at startup enabled - add Superhoarse to System Preferences > Users & Groups > Login Items")
        } else {
            print("Launch at startup disabled - remove Superhoarse from Login Items if present")
        }
    }
    
    private func updateDockVisibility(showInDock: Bool) {
        let newPolicy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        NSApp.setActivationPolicy(newPolicy)
        
        // Store the preference for use on next launch
        UserDefaults.standard.set(showInDock, forKey: "showInDock")
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
// COVERAGE_EXCLUDE_END
