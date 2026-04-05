import AudioToolbox
import SwiftUI

@main
struct HomeonTVApp: App {
    @StateObject private var store = HomeStore()

    var body: some Scene {
        WindowGroup {
            HomeRootView()
                .environmentObject(store)
        }
    }
}

enum HomeLaunchState {
    case loading
    case success
}

enum HomeonTVTheme {
    static let backgroundGradient = LinearGradient(
        colors: [Color(red: 0.05, green: 0.09, blue: 0.17), Color(red: 0.03, green: 0.16, blue: 0.2), Color(red: 0.08, green: 0.08, blue: 0.16)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [Color.white.opacity(0.26), Color.white.opacity(0.06)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardStroke = Color.white.opacity(0.18)
    static let softShadow = Color.black.opacity(0.28)
    static let surfaceTint = Color.white.opacity(0.08)
    static let cardFill = LinearGradient(
        colors: [Color.white.opacity(0.16), Color.white.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct HomeonTVCardStyle: ViewModifier {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 22) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(HomeonTVTheme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(HomeonTVTheme.cardStroke, lineWidth: 1)
                    )
            )
            .shadow(color: HomeonTVTheme.softShadow, radius: 16, x: 0, y: 10)
    }
}

extension View {
    func homeonTVCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(HomeonTVCardStyle(cornerRadius: cornerRadius))
    }
}

enum LaunchFeedbackPlayer {
    static func playSuccessChime() {
        // Closest public tvOS system tone to the Apple Pay-style confirmation chime.
        AudioServicesPlaySystemSound(1114)
    }

    static func playPaymentTapTone() {
        AudioServicesPlaySystemSound(1114)
    }
}

struct HomeLaunchOverlayView: View {
    let state: HomeLaunchState

    @State private var spin = false
    @State private var pulse = false

    private var accentColor: Color {
        switch state {
        case .loading:
            return .cyan
        case .success:
            return .green
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.36)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.12, green: 0.46, blue: 0.95), Color(red: 0.03, green: 0.23, blue: 0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 170, height: 170)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: accentColor.opacity(0.4), radius: pulse ? 42 : 18)

                    Image(systemName: "house.fill")
                        .font(.system(size: 74, weight: .semibold))
                        .foregroundStyle(.white)

                    Circle()
                        .trim(from: 0.14, to: 0.92)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: 196, height: 196)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .animation(
                            state == .loading ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .easeOut(duration: 0.4),
                            value: spin
                        )
                        .scaleEffect(state == .success ? 1.02 : 1.0)
                }

                Text(state == .loading ? "Loading Home" : "Home Connected")
                    .font(.title3.weight(.semibold))

                Text(state == .loading ? "Syncing accessories and scenes" : "Authenticated successfully")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(26)
            .homeonTVCard(cornerRadius: 30)
            .scaleEffect(state == .success ? 1.02 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state)
        }
        .onAppear {
            spin = true
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
