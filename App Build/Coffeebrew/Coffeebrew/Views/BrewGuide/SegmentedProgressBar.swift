import SwiftUI

struct SegmentedProgressBar: View {
    let totalSteps: Int
    let currentStep: Int
    let accentColor: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...totalSteps, id: \.self) { step in
                Capsule()
                    .fill(segmentColor(for: step))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        if step == currentStep {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(accentColor)
                                    .frame(width: geo.size.width * 0.5)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                            .repeatForever(autoreverses: true),
                                        value: currentStep
                                    )
                            }
                        }
                    }
                    .animation(.spring(response: 0.4), value: currentStep)
            }
        }
        .frame(height: 3)
        .accessibilityLabel("Step \(currentStep) of \(totalSteps)")
    }

    private func segmentColor(for step: Int) -> Color {
        if step < currentStep { return accentColor }
        if step == currentStep { return accentColor.opacity(0.3) }
        return Constants.Colors.primaryColor.opacity(0.06)
    }
}
