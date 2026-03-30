import SwiftUI

struct WaterCalloutView: View {
    let targetMl: Double
    @Binding var useFluidOunces: Bool
    let stepTitle: String
    let isBloomStep: Bool

    @State private var appeared = false
    @State private var flashOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: isBloomStep ? "drop.circle" : "drop.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Constants.Colors.accentGold)
                Text(isBloomStep ? "Bloom water" : "Add water")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(Constants.Colors.accentGold)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedAmount)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        useFluidOunces.toggle()
                    }
                } label: {
                    Text(unitLabel)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(Constants.Colors.accentGold.opacity(0.6))
                        .padding(.bottom, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Switch to \(useFluidOunces ? "milliliters" : "fluid ounces")")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                .fill(Constants.Colors.accentGold.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                .fill(Constants.Colors.accentGold.opacity(flashOpacity))
                .allowsHitTesting(false)
        )
        .scaleEffect(appeared ? 1.0 : 0.88)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                appeared = true
            }
            withAnimation(.easeIn(duration: 0.08)) { flashOpacity = 0.18 }
            withAnimation(.easeOut(duration: 0.35).delay(0.08)) { flashOpacity = 0 }
        }
        .onChange(of: targetMl) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                appeared = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                    appeared = true
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var formattedAmount: String {
        if useFluidOunces {
            return String(format: "%.1f", targetMl / 29.5735)
        }
        return String(format: "%.0f", targetMl)
    }

    private var unitLabel: String {
        useFluidOunces ? "fl oz" : "ml"
    }

    private var accessibilityText: String {
        "\(isBloomStep ? "Bloom water" : "Add water"): \(formattedAmount) \(unitLabel)"
    }
}
