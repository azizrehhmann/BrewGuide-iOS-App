import SwiftUI
import CoreData

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

    func elevatedCardStyle() -> some View {
        modifier(ElevatedCardModifier())
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
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ? Constants.Shadows.darkBorderColor : .black.opacity(0.04),
                        lineWidth: colorScheme == .dark ? Constants.Shadows.darkBorderWidth : 0.5
                    )
            )
            .shadow(
                color: colorScheme == .dark ? .clear : Constants.Shadows.cardColor,
                radius: Constants.Shadows.cardRadius, x: 0, y: Constants.Shadows.cardY
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

/// List and grid cards: a hairline, no shadow. Only `elevatedCardStyle` lifts off the page.
struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ? Constants.Shadows.darkBorderColor : Constants.Colors.primaryColor.opacity(0.08),
                        lineWidth: colorScheme == .dark ? Constants.Shadows.darkBorderWidth : 0.5
                    )
            )
    }
}

struct ElevatedCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark
                            ? Constants.Shadows.darkBorderColor
                            : Constants.Colors.accentGold.opacity(0.12),
                        lineWidth: colorScheme == .dark ? Constants.Shadows.darkBorderWidth : 0.5
                    )
            )
            .shadow(
                color: colorScheme == .dark ? .clear : Constants.Shadows.elevatedColor,
                radius: Constants.Shadows.elevatedRadius, x: 0, y: Constants.Shadows.elevatedY
            )
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle { ScaleButtonStyle() }
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

// MARK: - Double Rounding
extension Double {
    /// Parses what a user typed on a decimal keypad: "12,5" in de/fr regions, "12.5" elsewhere.
    init?(userInput: String) {
        self.init(userInput.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
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
            ZStack {
                Circle()
                    .fill(Constants.Colors.accentGold.opacity(0.08))
                    .frame(width: 88, height: 88)

                Image(systemName: icon)
                    .font(.system(size: 52, weight: .light, design: .rounded))
                    .foregroundStyle(Constants.Colors.accentGold.opacity(0.6))
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(Constants.Typography.headline)
                    .foregroundStyle(Constants.Colors.primaryColor)

                Text(message)
                    .font(Constants.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

extension NSManagedObjectContext {
    /// Saves pending changes. Returns false (and logs) if there is no store or the save throws.
    /// Checks for stores first because saving without one raises an NSException that `try` can't catch.
    func trySave() -> Bool {
        guard hasChanges else { return true }
        guard let coordinator = persistentStoreCoordinator, !coordinator.persistentStores.isEmpty else {
            print("Core Data: cannot save — no persistent stores loaded")
            return false
        }
        do {
            try save()
            return true
        } catch {
            print("Core Data save error: \(error)")
            return false
        }
    }
}
