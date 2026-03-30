import SwiftUI
import ActivityKit
import WidgetKit

struct BrewLockScreenView: View {
    let context: ActivityViewContext<BrewActivityAttributes>

    var body: some View {
        let state = context.state
        let attrs = context.attributes

        HStack(spacing: 14) {
            // Left: circular progress
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(
                        from: 0,
                        to: Double(state.currentStep) / Double(attrs.totalSteps)
                    )
                    .stroke(Color.brewGold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)

                VStack(spacing: 0) {
                    Text("\(state.currentStep)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("of \(attrs.totalSteps)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            // Centre: step details
            VStack(alignment: .leading, spacing: 4) {
                Text(attrs.techniqueName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)

                Text(state.stepTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(state.truncatedInstruction)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)

                // Water callout
                if let water = state.waterAmountMl, water > 0 {
                    Label(String(format: "%.0f ml", water), systemImage: "drop.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.brewGold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: timer
            VStack(alignment: .trailing, spacing: 2) {
                if state.hasTimer {
                    if state.isTimerPaused {
                        Text(formatSeconds(state.pausedSecondsRemaining))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.5))
                        Text("paused")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                    } else if let endTime = state.stepEndTime {
                        Text(timerInterval: Date()...endTime, countsDown: true)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.brewGold)
                        Text("remaining")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    Image(systemName: state.isLastStep ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(state.isLastStep ? Color.brewGold : .white.opacity(0.7))
                }
            }
            .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(16)
        .activityBackgroundTint(Color.black.opacity(0.75))
        .activitySystemActionForegroundColor(.white)
    }
}
