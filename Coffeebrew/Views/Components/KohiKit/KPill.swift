import SwiftUI

struct KPill: View {
    let text: String
    var icon: String? = nil
    var variant: Variant = .gold

    enum Variant { case gold, ghost, filled, time }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
            }
            Text(text)
                .font(variant == .time ? Constants.Typography.mono(10) : Constants.Typography.sans(10, weight: .semibold))
                .textCase(variant == .time ? .none : .uppercase)
                .tracking(variant == .time ? 0.2 : 0.4)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(backgroundColor, in: Capsule())
    }

    private var foregroundColor: Color {
        switch variant {
        case .filled: return .white
        default: return Constants.Colors.accentGold
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .gold: return Constants.Colors.accentGold.opacity(0.08)
        case .ghost: return Constants.Colors.primaryColor.opacity(0.06)
        case .filled: return Constants.Colors.accentGold
        case .time: return Constants.Colors.accentGold.opacity(0.08)
        }
    }
}
