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
        static let cornerRadius: CGFloat = 24
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

        // Custom font helpers for KohiKit components
        static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom("PlayfairDisplay-Regular", size: size).weight(weight)
        }
        static func displayItalic(_ size: CGFloat) -> Font {
            .custom("PlayfairDisplay-Italic", size: size)
        }
        static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom("DMSans-Regular", size: size).weight(weight)
        }
        static func mono(_ size: CGFloat) -> Font {
            .custom("DMMono-Medium", size: size)
        }
    }

    // MARK: - Animation
    enum Animation {
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.25)
        static let spring: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 0.85)
        static let gentle: SwiftUI.Animation = .spring(response: 0.5, dampingFraction: 0.9)
    }

    // MARK: - Shadows
    enum Shadows {
        static let cardColor: Color = .black.opacity(0.07)
        static let cardRadius: CGFloat = 12
        static let cardY: CGFloat = 4
        static let elevatedColor: Color = .black.opacity(0.10)
        static let elevatedRadius: CGFloat = 20
        static let elevatedY: CGFloat = 6
        static let darkBorderColor: Color = .white.opacity(0.06)
        static let darkBorderWidth: CGFloat = 0.5
    }

    // MARK: - Category Tints
    enum CategoryTints {
        static func tint(for category: String) -> Color {
            switch category {
            case "Pour Over": return .blue
            case "Immersion": return Color(hex: 0x8B6914)
            case "Pressure": return Color(hex: 0xCC4422)
            case "Cold Brew": return .teal
            case "Stovetop & Traditional": return .orange
            case "Machine": return .gray
            default: return Colors.accentGold
            }
        }
    }
}
