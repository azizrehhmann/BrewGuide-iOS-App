import XCTest
@testable import Coffeebrew

final class BrewLiveActivityServiceTests: XCTestCase {

    func test_makeState_withTimer_setsEndTime() {
        let state = BrewLiveActivityService.makeState(
            currentStep: 2,
            totalSteps: 5,
            stepTitle: "Second pour",
            stepInstruction: "Pour 120g slowly.",
            stepDurationSeconds: 45,
            totalElapsedSeconds: 55,
            isTimerRunning: true,
            isTimerPaused: false,
            pausedSecondsRemaining: 0,
            waterAmountMl: 120
        )
        XCTAssertNotNil(state.stepEndTime)
        XCTAssertTrue(state.hasTimer)
        XCTAssertFalse(state.isTimerPaused)
        XCTAssertFalse(state.isLastStep)
    }

    func test_makeState_noTimer_nilEndTime() {
        let state = BrewLiveActivityService.makeState(
            currentStep: 1,
            totalSteps: 5,
            stepTitle: "Add coffee",
            stepInstruction: "Grind and add 20g.",
            stepDurationSeconds: 0,
            totalElapsedSeconds: 0,
            isTimerRunning: false,
            isTimerPaused: false,
            pausedSecondsRemaining: 0,
            waterAmountMl: nil
        )
        XCTAssertNil(state.stepEndTime)
        XCTAssertFalse(state.hasTimer)
    }

    func test_makeState_paused_nilEndTime() {
        let state = BrewLiveActivityService.makeState(
            currentStep: 3,
            totalSteps: 5,
            stepTitle: "Steep",
            stepInstruction: "Wait for drawdown.",
            stepDurationSeconds: 60,
            totalElapsedSeconds: 100,
            isTimerRunning: true,
            isTimerPaused: true,
            pausedSecondsRemaining: 23,
            waterAmountMl: nil
        )
        XCTAssertNil(state.stepEndTime)
        XCTAssertTrue(state.isTimerPaused)
        XCTAssertEqual(state.pausedSecondsRemaining, 23)
    }

    func test_makeState_lastStep_flagSet() {
        let state = BrewLiveActivityService.makeState(
            currentStep: 6,
            totalSteps: 6,
            stepTitle: "Serve",
            stepInstruction: "Remove dripper and serve.",
            stepDurationSeconds: 0,
            totalElapsedSeconds: 240,
            isTimerRunning: false,
            isTimerPaused: false,
            pausedSecondsRemaining: 0,
            waterAmountMl: nil
        )
        XCTAssertTrue(state.isLastStep)
    }

    func test_truncatedInstruction_longText_truncates() {
        let state = BrewLiveActivityService.makeState(
            currentStep: 1, totalSteps: 3,
            stepTitle: "Test",
            stepInstruction: String(repeating: "A", count: 80),
            stepDurationSeconds: 30, totalElapsedSeconds: 0,
            isTimerRunning: false, isTimerPaused: false,
            pausedSecondsRemaining: 0, waterAmountMl: nil
        )
        XCTAssertEqual(state.truncatedInstruction.count, 58)
        XCTAssertTrue(state.truncatedInstruction.hasSuffix("\u{2026}"))
    }

    func test_truncatedInstruction_shortText_unchanged() {
        let short = "Pour slowly."
        let state = BrewLiveActivityService.makeState(
            currentStep: 1, totalSteps: 3,
            stepTitle: "Test",
            stepInstruction: short,
            stepDurationSeconds: 30, totalElapsedSeconds: 0,
            isTimerRunning: false, isTimerPaused: false,
            pausedSecondsRemaining: 0, waterAmountMl: nil
        )
        XCTAssertEqual(state.truncatedInstruction, short)
    }
}
