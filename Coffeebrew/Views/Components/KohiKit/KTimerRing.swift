import SwiftUI

struct KTimerRing: View {
    let progress: Double
    let remaining: Int
    var total: Int? = nil
    var phase: String? = nil
    var size: CGFloat = 240

    private var mins: Int { max(0, remaining) / 60 }
    private var secs: Int { max(0, remaining) % 60 }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Constants.Colors.primaryColor.opacity(0.06), lineWidth: 3)
            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Constants.Colors.accentGold,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            // Center content
            VStack(spacing: 4) {
                if let phase {
                    Text(phase.uppercased())
                        .font(Constants.Typography.mono(10))
                        .foregroundStyle(Constants.Colors.accentGold)
                        .tracking(1.4)
                }
                HStack(spacing: 0) {
                    Text("\(mins)")
                        .font(Constants.Typography.display(64, weight: .medium))
                    Text(":")
                        .font(Constants.Typography.display(64, weight: .medium))
                        .foregroundStyle(Constants.Colors.primaryColor.opacity(0.35))
                    Text(String(format: "%02d", secs))
                        .font(Constants.Typography.display(64, weight: .medium))
                }
                .foregroundStyle(Constants.Colors.primaryColor)
                .monospacedDigit()

                if let total {
                    Text("of \(total / 60):\(String(format: "%02d", total % 60))")
                        .font(Constants.Typography.mono(11))
                        .foregroundStyle(Constants.Colors.primaryColor.opacity(0.35))
                }
            }
        }
        .frame(width: size, height: size)
    }
}
