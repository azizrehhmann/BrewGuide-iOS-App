import SwiftUI

struct BeanProgressRing: View {
    let remaining: Double
    let total: Double
    let ringSize: CGFloat

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(remaining / total, 1.0)
    }

    private var ringColor: Color {
        if fraction > 0.5 {
            return Constants.Colors.accentGold
        } else if fraction > 0.2 {
            return Constants.Colors.accentGold.opacity(0.6)
        } else {
            return Constants.Colors.primaryColor.opacity(0.2)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Constants.Colors.primaryColor.opacity(0.06), lineWidth: 4)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(Int(remaining))g")
                    .font(.system(size: ringSize * 0.2, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text(formattedTotal)
                    .font(.system(size: ringSize * 0.11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(remaining)) of \(formattedTotal) remaining")
    }

    private var formattedTotal: String {
        if total >= 1000 {
            return String(format: "%.0f,000g", total / 1000)
        }
        return "\(Int(total))g"
    }
}
