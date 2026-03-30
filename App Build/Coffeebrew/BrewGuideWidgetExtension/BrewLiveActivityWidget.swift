import ActivityKit
import WidgetKit
import SwiftUI

struct BrewLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BrewActivityAttributes.self) { context in
            // Lock Screen / StandBy view
            BrewLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: methodIcon(context.attributes.methodCategory))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.brewGold)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.equipmentName)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.55))
                            Text(context.attributes.techniqueName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    let state = context.state
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Step \(state.currentStep) of \(context.attributes.totalSteps)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))

                        // Step progress pills
                        HStack(spacing: 3) {
                            ForEach(1...min(context.attributes.totalSteps, 7), id: \.self) { i in
                                Capsule()
                                    .fill(i <= state.currentStep ? Color.brewGold : Color.white.opacity(0.2))
                                    .frame(width: i == state.currentStep ? 14 : 6, height: 4)
                                    .animation(.spring(response: 0.3), value: state.currentStep)
                            }
                            if context.attributes.totalSteps > 7 {
                                Text("\u{2026}")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    BrewExpandedView(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }

            } compactLeading: {
                BrewCompactLeadingView(context: context)
            } compactTrailing: {
                BrewCompactTrailingView(context: context)
            } minimal: {
                BrewMinimalView(context: context)
            }
            .widgetURL(URL(string: "brewguide://brew/resume"))
            .keylineTint(Color.brewGold)
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension BrewActivityAttributes {
    static var preview: BrewActivityAttributes {
        BrewActivityAttributes(
            techniqueName: "James Hoffmann Method",
            equipmentName: "Hario V60",
            totalSteps: 6,
            methodCategory: "Pour Over"
        )
    }
}

extension BrewActivityAttributes.ContentState {
    static var previewStep2: BrewActivityAttributes.ContentState {
        .init(
            currentStep: 2,
            stepTitle: "Second pour",
            stepInstruction: "Pour 120g in a slow spiral from the centre outward.",
            stepDurationSeconds: 45,
            stepEndTime: Date().addingTimeInterval(38),
            totalElapsedSeconds: 52,
            isLastStep: false,
            isTimerPaused: false,
            pausedSecondsRemaining: 0,
            waterAmountMl: 120
        )
    }

    static var previewPaused: BrewActivityAttributes.ContentState {
        .init(
            currentStep: 3,
            stepTitle: "Drawdown",
            stepInstruction: "Wait for the coffee to draw down through the filter.",
            stepDurationSeconds: 60,
            stepEndTime: nil,
            totalElapsedSeconds: 110,
            isLastStep: false,
            isTimerPaused: true,
            pausedSecondsRemaining: 23,
            waterAmountMl: nil
        )
    }

    static var previewNoTimer: BrewActivityAttributes.ContentState {
        .init(
            currentStep: 6,
            stepTitle: "Serve",
            stepInstruction: "Remove the dripper and pour into your cup.",
            stepDurationSeconds: 0,
            stepEndTime: nil,
            totalElapsedSeconds: 210,
            isLastStep: true,
            isTimerPaused: false,
            pausedSecondsRemaining: 0,
            waterAmountMl: nil
        )
    }
}

#Preview("Lock Screen — Timer running", as: .content,
         using: BrewActivityAttributes.preview) {
    BrewLiveActivityWidget()
} contentStates: {
    BrewActivityAttributes.ContentState.previewStep2
    BrewActivityAttributes.ContentState.previewPaused
    BrewActivityAttributes.ContentState.previewNoTimer
}

#Preview("Dynamic Island — Compact", as: .dynamicIsland(.compact),
         using: BrewActivityAttributes.preview) {
    BrewLiveActivityWidget()
} contentStates: {
    BrewActivityAttributes.ContentState.previewStep2
}

#Preview("Dynamic Island — Expanded", as: .dynamicIsland(.expanded),
         using: BrewActivityAttributes.preview) {
    BrewLiveActivityWidget()
} contentStates: {
    BrewActivityAttributes.ContentState.previewStep2
    BrewActivityAttributes.ContentState.previewPaused
}

#Preview("Dynamic Island — Minimal", as: .dynamicIsland(.minimal),
         using: BrewActivityAttributes.preview) {
    BrewLiveActivityWidget()
} contentStates: {
    BrewActivityAttributes.ContentState.previewStep2
}
#endif
