import SwiftUI

struct CumulativePourBar: View {
    let previousMl: Double
    let currentStepMl: Double
    let totalRecipeMl: Double

    @State private var fillFraction: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var prevFraction: Double {
        guard totalRecipeMl > 0 else { return 0 }
        return min(previousMl / totalRecipeMl, 1.0)
    }

    private var targetFraction: Double {
        guard totalRecipeMl > 0 else { return 0 }
        return min((previousMl + currentStepMl) / totalRecipeMl, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Constants.Colors.primaryColor.opacity(0.06))
                        .frame(height: 6)

                    Capsule()
                        .fill(Constants.Colors.accentGold.opacity(0.3))
                        .frame(width: geo.size.width * prevFraction, height: 6)

                    Capsule()
                        .fill(Constants.Colors.accentGold)
                        .frame(width: geo.size.width * fillFraction, height: 6)
                        .animation(
                            reduceMotion ? .none : .easeOut(duration: 0.55).delay(0.2),
                            value: fillFraction
                        )
                }
            }
            .frame(height: 6)

            HStack {
                Text(String(format: "%.0f ml so far", previousMl + currentStepMl))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f ml total", totalRecipeMl))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            fillFraction = targetFraction
        }
        .onChange(of: currentStepMl) { _, _ in
            fillFraction = prevFraction
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                fillFraction = targetFraction
            }
        }
        .accessibilityLabel(
            String(format: "%.0f of %.0f ml added", previousMl + currentStepMl, totalRecipeMl)
        )
    }
}
