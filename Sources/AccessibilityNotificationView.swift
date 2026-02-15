// COVERAGE_EXCLUDE_START - SwiftUI Views require UI testing framework, not unit tests
// SwiftUI views are declarative and best tested through UI automation tests
// Unit testing SwiftUI views requires complex mocking of the entire SwiftUI framework
import SwiftUI

struct AccessibilityNotificationView: View {
    @EnvironmentObject var appState: AppState
    @State private var showNotification: Bool = false
    @State private var pulseAnimation: Bool = false
    @State private var glowIntensity: Double = 0.5
    @State private var floatAnimation: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            // Animated lock icon with synthwave glow
            ZStack {
                // Background glow rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.3 - Double(index) * 0.1),
                                    Color(red: 1.0, green: 0.2, blue: 0.0).opacity(0.3 - Double(index) * 0.1)
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

                // Main lock icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.5, blue: 0.0),
                                Color(red: 1.0, green: 0.3, blue: 0.0),
                                Color(red: 1.0, green: 0.1, blue: 0.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.5, blue: 0.0), radius: 8)
                    .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.0), radius: 12)
                    .scaleEffect(floatAnimation ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: floatAnimation)
            }

            // Main message
            VStack(spacing: 8) {
                Text("ACCESSIBILITY REQUIRED")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.0))

                Text("Open Settings to grant permission")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(minWidth: 300)
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.1),
                            Color(red: 0.2, green: 0.05, blue: 0.0).opacity(0.2),
                            Color(red: 0.15, green: 0.02, blue: 0.0).opacity(0.3)
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
                                    Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.4),
                                    Color(red: 1.0, green: 0.2, blue: 0.0).opacity(0.4)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.3), radius: 16)
                .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.0).opacity(0.2), radius: 20)
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

            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
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
            appState.hideAccessibilityNotification()
        }
    }
}
// COVERAGE_EXCLUDE_END
