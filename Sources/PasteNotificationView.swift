// COVERAGE_EXCLUDE_START - SwiftUI Views require UI testing framework, not unit tests
// SwiftUI views are declarative and best tested through UI automation tests
// Unit testing SwiftUI views requires complex mocking of the entire SwiftUI framework
import SwiftUI

struct PasteNotificationView: View {
    @EnvironmentObject var appState: AppState
    @State private var showNotification: Bool = false
    @State private var pulseAnimation: Bool = false
    @State private var glowIntensity: Double = 0.5
    @State private var floatAnimation: Bool = false
    
    let transcribedText: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Animated clipboard icon with synthwave glow
            ZStack {
                // Background glow rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.3 - Double(index) * 0.1),
                                    Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.3 - Double(index) * 0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 60 + CGFloat(index * 15), height: 60 + CGFloat(index * 15))
                        .scaleEffect(pulseAnimation ? 1.2 + Double(index) * 0.1 : 1.0)
                        .opacity(pulseAnimation ? 0.0 : 1.0)
                        .animation(
                            .easeOut(duration: 1.5 + Double(index) * 0.2)
                            .repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                }
                
                // Main clipboard icon
                Image(systemName: "clipboard.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.0, blue: 1.0),
                                Color(red: 0.8, green: 0.0, blue: 1.0),
                                Color(red: 0.0, green: 0.8, blue: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.0, blue: 1.0), radius: 8)
                    .shadow(color: Color(red: 0.0, green: 0.8, blue: 1.0), radius: 12)
                    .scaleEffect(floatAnimation ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: floatAnimation)
            }
            
            // Main message with synthwave styling
            VStack(spacing: 8) {
                Text("TEXT COPIED TO CLIPBOARD")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.0, blue: 1.0),
                                Color(red: 0.0, green: 1.0, blue: 0.5)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.0, blue: 1.0), radius: 3)
                    .tracking(1)
                
                Text("Press ⌘V to paste")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            // Command V visualization with neon effect
            HStack(spacing: 12) {
                // Command key
                VStack(spacing: 4) {
                    Text("⌘")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                        .shadow(color: Color(red: 0.0, green: 0.8, blue: 1.0), radius: 6)
                    
                    Text("CMD")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 0.0, green: 0.8, blue: 1.0).opacity(glowIntensity), lineWidth: 2)
                        )
                        .shadow(color: Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.4), radius: 8)
                )
                
                // Plus symbol
                Text("+")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                // V key
                VStack(spacing: 4) {
                    Text("V")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 1.0, green: 0.0, blue: 1.0))
                        .shadow(color: Color(red: 1.0, green: 0.0, blue: 1.0), radius: 6)
                    
                    Text("PASTE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 1.0, green: 0.0, blue: 1.0).opacity(glowIntensity), lineWidth: 2)
                        )
                        .shadow(color: Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.4), radius: 8)
                )
            }
            
            // Preview of transcribed text (truncated)
            if !transcribedText.isEmpty {
                VStack(spacing: 6) {
                    Text("TRANSCRIBED:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                    
                    Text(transcribedText.count > 60 ? String(transcribedText.prefix(60)) + "..." : transcribedText)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(red: 0.8, green: 0.8, blue: 1.0))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.15),
                            Color(red: 0.1, green: 0.0, blue: 0.2).opacity(0.3),
                            Color(red: 0.05, green: 0.0, blue: 0.15).opacity(0.4)
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
                                    Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.6),
                                    Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color(red: 1.0, green: 0.0, blue: 1.0).opacity(0.3), radius: 16)
                .shadow(color: Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.2), radius: 20)
                .shadow(color: Color.black.opacity(0.6), radius: 30)
        )
        .opacity(showNotification ? 1.0 : 0.0)
        .scaleEffect(showNotification ? 1.0 : 0.7)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showNotification)
        .onAppear {
            showNotification = true
            pulseAnimation = true
            floatAnimation = true
            startGlowAnimation()
            
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                dismissNotification()
            }
        }
        .onTapGesture {
            dismissNotification()
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }
    }
    
    private func dismissNotification() {
        showNotification = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            appState.hidePasteNotification()
        }
    }
}
// COVERAGE_EXCLUDE_END