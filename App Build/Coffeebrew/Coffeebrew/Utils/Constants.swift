import SwiftUI

enum Constants {
    // MARK: - Colors
    enum Colors {
        static let background = Color("Background")
        static let accent = Color("Accent")
        static let cardBackground = Color("CardBackground")
        static let subtleGold = Color("SubtleGold")

        // Adaptive primary text color
        static let primaryColor = Color("EspressoBrown")

        // Non-adaptive references
        static let backgroundLight = Color(hex: 0xF9F8F5)
        static let backgroundDark = Color(hex: 0x131313)
        static let accentGold = Color("Accent")
    }

    // MARK: - Layout
    enum Layout {
        static let cardWidth: CGFloat = 160
        static let cardHeight: CGFloat = 200
        static let cornerRadius: CGFloat = 20
        static let smallCornerRadius: CGFloat = 12
        static let minTouchTarget: CGFloat = 44
        static let horizontalPadding: CGFloat = 20
        static let verticalSpacing: CGFloat = 16
        static let cardSpacing: CGFloat = 12
    }

    // MARK: - Typography
    enum Typography {
        static let largeTitle: Font = .system(.largeTitle, design: .rounded, weight: .bold)
        static let title: Font = .system(.title2, design: .rounded, weight: .semibold)
        static let headline: Font = .system(.headline, design: .rounded, weight: .semibold)
        static let body: Font = .system(.body, design: .rounded)
        static let caption: Font = .system(.caption, design: .rounded)
        static let callout: Font = .system(.callout, design: .rounded, weight: .medium)
    }

    // MARK: - Animation
    enum Animation {
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.25)
        static let spring: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 0.85)
        static let gentle: SwiftUI.Animation = .spring(response: 0.5, dampingFraction: 0.9)
    }
}
