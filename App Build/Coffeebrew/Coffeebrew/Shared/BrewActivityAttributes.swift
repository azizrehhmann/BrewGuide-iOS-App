import ActivityKit
import Foundation

struct BrewActivityAttributes: ActivityAttributes {

    // MARK: - Static data (set at launch, never changes during the activity)

    let techniqueName: String
    let equipmentName: String
    let totalSteps: Int
    let methodCategory: String   // e.g. "Pour Over", used for icon selection

    // MARK: - Dynamic state (updated on every step change)

    struct ContentState: Codable, Hashable {
        let currentStep: Int              // 1-based
        let stepTitle: String             // e.g. "Second pour"
        let stepInstruction: String       // truncated to ~60 chars for display
        let stepDurationSeconds: Int      // 0 = no timer for this step
        let stepEndTime: Date?            // absolute end time for system timer (nil if no timer)
        let totalElapsedSeconds: Int      // cumulative brew time so far
        let isLastStep: Bool
        let isTimerPaused: Bool
        let pausedSecondsRemaining: Int   // only valid when isTimerPaused == true
        let waterAmountMl: Double?        // shown if this step adds water
    }
}

// MARK: - Convenience

extension BrewActivityAttributes.ContentState {
    var hasTimer: Bool { stepDurationSeconds > 0 }

    var truncatedInstruction: String {
        stepInstruction.count > 60
            ? String(stepInstruction.prefix(57)) + "\u{2026}"
            : stepInstruction
    }
}
