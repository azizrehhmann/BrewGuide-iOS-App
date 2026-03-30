import ActivityKit
import Combine
import Foundation
import os.log

private let logger = Logger(subsystem: "Aziz.Coffeebrew", category: "LiveActivity")

final class BrewLiveActivityService: ObservableObject {

    static let shared = BrewLiveActivityService()

    private var currentActivity: Activity<BrewActivityAttributes>?

    // MARK: - Start

    func startActivity(
        techniqueName: String,
        equipmentName: String,
        methodCategory: String,
        totalSteps: Int,
        firstStep: BrewActivityAttributes.ContentState
    ) {
        let authInfo = ActivityAuthorizationInfo()
        logger.info("Live Activities enabled: \(authInfo.areActivitiesEnabled)")

        guard authInfo.areActivitiesEnabled else {
            logger.warning("Live Activities not enabled by user")
            return
        }

        // End any existing activities synchronously before starting new one
        for activity in Activity<BrewActivityAttributes>.activities {
            logger.info("Ending stale activity: \(activity.id)")
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        currentActivity = nil

        let attributes = BrewActivityAttributes(
            techniqueName: techniqueName,
            equipmentName: equipmentName,
            totalSteps: totalSteps,
            methodCategory: methodCategory
        )

        let content = ActivityContent(
            state: firstStep,
            staleDate: firstStep.stepEndTime.map { $0.addingTimeInterval(30) }
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            logger.info("Live Activity started: \(self.currentActivity?.id ?? "nil")")
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    // MARK: - Update on step change

    func updateStep(_ newState: BrewActivityAttributes.ContentState) {
        guard let activity = currentActivity else {
            logger.warning("updateStep called but no current activity")
            return
        }

        let content = ActivityContent(
            state: newState,
            staleDate: newState.stepEndTime.map { $0.addingTimeInterval(30) }
        )

        Task {
            await activity.update(content)
            logger.info("Activity updated: step \(newState.currentStep)")
        }
    }

    // MARK: - Pause / resume timer

    func pauseTimer(secondsRemaining: Int) {
        guard let activity = currentActivity else { return }
        let current = activity.content.state
        let updated = BrewActivityAttributes.ContentState(
            currentStep: current.currentStep,
            stepTitle: current.stepTitle,
            stepInstruction: current.stepInstruction,
            stepDurationSeconds: current.stepDurationSeconds,
            stepEndTime: nil,
            totalElapsedSeconds: current.totalElapsedSeconds,
            isLastStep: current.isLastStep,
            isTimerPaused: true,
            pausedSecondsRemaining: secondsRemaining,
            waterAmountMl: current.waterAmountMl
        )
        Task {
            await activity.update(ActivityContent(state: updated, staleDate: nil))
        }
    }

    func resumeTimer(newEndTime: Date) {
        guard let activity = currentActivity else { return }
        let current = activity.content.state
        let updated = BrewActivityAttributes.ContentState(
            currentStep: current.currentStep,
            stepTitle: current.stepTitle,
            stepInstruction: current.stepInstruction,
            stepDurationSeconds: current.stepDurationSeconds,
            stepEndTime: newEndTime,
            totalElapsedSeconds: current.totalElapsedSeconds,
            isLastStep: current.isLastStep,
            isTimerPaused: false,
            pausedSecondsRemaining: 0,
            waterAmountMl: current.waterAmountMl
        )
        Task {
            await activity.update(ActivityContent(state: updated, staleDate: newEndTime.addingTimeInterval(30)))
        }
    }

    // MARK: - End

    func endActivity(animated: Bool = true) {
        guard let activity = currentActivity else { return }
        logger.info("Ending activity: \(activity.id)")
        Task {
            await activity.end(nil, dismissalPolicy: animated ? .default : .immediate)
            currentActivity = nil
        }
    }

    // MARK: - Helpers

    /// Build ContentState from the current step data
    static func makeState(
        currentStep: Int,
        totalSteps: Int,
        stepTitle: String,
        stepInstruction: String,
        stepDurationSeconds: Int,
        totalElapsedSeconds: Int,
        isTimerRunning: Bool,
        isTimerPaused: Bool,
        pausedSecondsRemaining: Int,
        waterAmountMl: Double?
    ) -> BrewActivityAttributes.ContentState {

        let endTime: Date? = (stepDurationSeconds > 0 && isTimerRunning && !isTimerPaused)
            ? Date().addingTimeInterval(Double(pausedSecondsRemaining > 0
                ? pausedSecondsRemaining
                : stepDurationSeconds))
            : nil

        return BrewActivityAttributes.ContentState(
            currentStep: currentStep,
            stepTitle: stepTitle,
            stepInstruction: stepInstruction,
            stepDurationSeconds: stepDurationSeconds,
            stepEndTime: endTime,
            totalElapsedSeconds: totalElapsedSeconds,
            isLastStep: currentStep == totalSteps,
            isTimerPaused: isTimerPaused,
            pausedSecondsRemaining: pausedSecondsRemaining,
            waterAmountMl: waterAmountMl
        )
    }
}
