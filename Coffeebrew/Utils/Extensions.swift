import SwiftUI

// MARK: - Color Hex Init
extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - View Modifiers
extension View {
    func brewCardStyle() -> some View {
        modifier(BrewCardModifier())
    }

    func adaptiveBackground() -> some View {
        modifier(AdaptiveBackgroundModifier())
    }

    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

struct BrewCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                colorScheme == .dark
                    ? Color(hex: 0x1E1E1E)
                    : .white
            )
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous))
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.04),
                radius: 12, x: 0, y: 4
            )
    }
}

struct AdaptiveBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Constants.Colors.background
                    .ignoresSafeArea()
            )
    }
}

struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.03),
                radius: 10, x: 0, y: 2
            )
    }
}

// MARK: - Int to Time String
extension Int {
    var formattedTime: String {
        let minutes = self / 60
        let seconds = self % 60
        if minutes > 0 && seconds > 0 {
            return "\(minutes) min \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(seconds)s"
        }
    }

    var shortFormattedTime: String {
        let minutes = self / 60
        let seconds = self % 60
        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
        return "0:\(String(format: "%02d", seconds))"
    }
}

// MARK: - Safe Array Subscript
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light, design: .rounded))
                .foregroundStyle(Constants.Colors.accentGold.opacity(0.5))

            VStack(spacing: 6) {
                Text(title)
                    .font(Constants.Typography.headline)
                    .foregroundStyle(Constants.Colors.primaryColor)

                Text(message)
                    .font(Constants.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
