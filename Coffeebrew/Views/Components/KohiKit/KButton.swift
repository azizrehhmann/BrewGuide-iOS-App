import SwiftUI

struct KButton: View {
    let title: String
    var icon: String? = nil
    var variant: Variant = .primary
    var fullWidth: Bool = true
    var disabled: Bool = false
    var action: () -> Void

    enum Variant { case primary, gold, ghost }

    var body: some View {
        Button(action: {
            if !disabled {
                HapticsManager.shared.impact(style: .light)
                action()
            }
        }) {
            HStack(spacing: 8) {
                Text(title)
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .font(Constants.Typography.sans(15, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 50)
            .padding(.horizontal, fullWidth ? 0 : 20)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                variant == .ghost
                    ? RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Constants.Colors.primaryColor.opacity(0.08), lineWidth: 0.5)
                    : nil
            )
        }
        .buttonStyle(.scale)
        .opacity(disabled ? 0.5 : 1)
        .allowsHitTesting(!disabled)
    }

    private var foregroundColor: Color {
        if disabled { return Constants.Colors.primaryColor.opacity(0.4) }
        switch variant {
        case .primary: return Constants.Colors.background
        case .gold: return .white
        case .ghost: return Constants.Colors.primaryColor
        }
    }

    private var backgroundColor: Color {
        if disabled { return Constants.Colors.primaryColor.opacity(0.12) }
        switch variant {
        case .primary: return Constants.Colors.primaryColor
        case .gold: return Constants.Colors.accentGold
        case .ghost: return .clear
        }
    }
}
