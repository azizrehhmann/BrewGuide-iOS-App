import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Compact leading (left of camera cutout)

struct BrewCompactLeadingView: View {
    let context: ActivityViewContext<BrewActivityAttributes>

    var body: some View {
        Image(systemName: methodIcon(context.attributes.methodCategory))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.brewGold)
            .frame(width: 28, height: 28)
    }
}

// MARK: - Compact trailing (right of camera cutout)

struct BrewCompactTrailingView: View {
    let context: ActivityViewContext<BrewActivityAttributes>

    var body: some View {
        let state = context.state

        Group {
            if state.hasTimer, let endTime = state.stepEndTime, !state.isTimerPaused {
                Text(timerInterval: Date()...endTime, countsDown: true)
                    .monospacedDigit()
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, alignment: .trailing)
            } else if state.isTimerPaused {
                Text(formatSeconds(state.pausedSecondsRemaining))
                    .monospacedDigit()
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Text("\(state.currentStep)/\(context.attributes.totalSteps)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.trailing, 4)
    }
}

// MARK: - Minimal (tiny dot or small view on non-Pro iPhones)

struct BrewMinimalView: View {
    let context: ActivityViewContext<BrewActivityAttributes>

    var body: some View {
        Image(systemName: "timer")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.brewGold)
    }
}

// MARK: - Expanded (tapped Dynamic Island)

struct BrewExpandedView: View {
    let context: ActivityViewContext<BrewActivityAttributes>

    var body: some View {
        let state = context.state
        let attrs = context.attributes

        HStack(alignment: .center, spacing: 16) {
            // Left: method icon + step progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(
                        from: 0,
                        to: Double(state.currentStep) / Double(attrs.totalSteps)
                    )
                    .stroke(Color.brewGold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                    .animation(.easeInOut(duration: 0.4), value: state.currentStep)

                Image(systemName: methodIcon(attrs.methodCategory))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }

            // Centre: step info
            VStack(alignment: .leading, spacing: 3) {
                Text("Step \(state.currentStep) of \(attrs.totalSteps)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))

                Text(state.stepTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(state.truncatedInstruction)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: timer
            VStack(alignment: .trailing, spacing: 2) {
                if state.hasTimer {
                    if state.isTimerPaused {
                        Text(formatSeconds(state.pausedSecondsRemaining))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.5))
                        Text("paused")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    } else if let endTime = state.stepEndTime {
                        Text(timerInterval: Date()...endTime, countsDown: true)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.brewGold)
                        Text("remaining")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    Image(systemName: state.isLastStep ? "checkmark.circle.fill" : "hand.tap.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(state.isLastStep ? Color.brewGold : .white.opacity(0.7))
                    Text(state.isLastStep ? "Last step" : "Tap when done")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(minWidth: 68, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Helpers

func methodIcon(_ category: String) -> String {
    switch category.lowercased() {
    case let c where c.contains("pour"):    return "drop.fill"
    case let c where c.contains("french"):  return "cup.and.saucer.fill"
    case let c where c.contains("aero"):    return "arrow.down.circle.fill"
    case let c where c.contains("espresso"): return "bolt.fill"
    case let c where c.contains("cold"):    return "snowflake"
    case let c where c.contains("moka"):    return "flame.fill"
    default:                                return "cup.and.saucer"
    }
}

func formatSeconds(_ total: Int) -> String {
    let m = total / 60
    let s = total % 60
    return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "0:%02d", s)
}

extension Color {
    static let brewGold = Color(
        .sRGB,
        red: Double(0xC8) / 255.0,
        green: Double(0x86) / 255.0,
        blue: Double(0x0A) / 255.0,
        opacity: 1.0
    )
}
