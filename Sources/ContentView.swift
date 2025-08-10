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
                
                RecordingStatusView()
                
                TranscriptionView()
                
                ControlsView()
            }
        }
        .padding()
        .frame(width: 400, height: 300)
        .background(Color(.windowBackgroundColor))
    }
}

struct HeaderView: View {
    var body: some View {
        VStack {
            Text("SuperWhisper Lite")
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

#Preview {
    ContentView()
        .environmentObject(AppState())
}