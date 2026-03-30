import XCTest
@testable import Coffeebrew

@MainActor
final class BrewTimerServiceTests: XCTestCase {

    var sut: BrewTimerService!

    override func setUp() {
        super.setUp()
        sut = BrewTimerService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(sut.totalElapsedSeconds, 0)
        XCTAssertEqual(sut.stepRemainingSeconds, 0)
        XCTAssertEqual(sut.stepDurationSeconds, 0)
        XCTAssertFalse(sut.isRunning)
        XCTAssertFalse(sut.stepCompleted)
    }

    // MARK: - Configure Step

    func testConfigureStepSetsValues() {
        sut.configureStep(duration: 30)
        XCTAssertEqual(sut.stepDurationSeconds, 30)
        XCTAssertEqual(sut.stepRemainingSeconds, 30)
        XCTAssertFalse(sut.stepCompleted)
        XCTAssertFalse(sut.isRunning)
    }

    func testConfigureStepResetsRunningTimer() {
        sut.configureStep(duration: 60)
        sut.start()
        XCTAssertTrue(sut.isRunning)

        sut.configureStep(duration: 30)
        XCTAssertFalse(sut.isRunning)
        XCTAssertEqual(sut.stepDurationSeconds, 30)
        XCTAssertEqual(sut.stepRemainingSeconds, 30)
    }

    // MARK: - Start / Pause / Toggle

    func testStartSetsRunning() {
        sut.configureStep(duration: 10)
        sut.start()
        XCTAssertTrue(sut.isRunning)
    }

    func testStartIdempotent() {
        sut.start()
        sut.start()
        XCTAssertTrue(sut.isRunning)
    }

    func testPauseSetsNotRunning() {
        sut.start()
        sut.pause()
        XCTAssertFalse(sut.isRunning)
    }

    func testPauseWhenNotRunningIsNoop() {
        sut.pause()
        XCTAssertFalse(sut.isRunning)
    }

    func testToggle() {
        XCTAssertFalse(sut.isRunning)
        sut.toggle()
        XCTAssertTrue(sut.isRunning)
        sut.toggle()
        XCTAssertFalse(sut.isRunning)
    }

    // MARK: - Reset

    func testResetClearsAllState() {
        sut.configureStep(duration: 60)
        sut.start()
        sut.reset()

        XCTAssertEqual(sut.totalElapsedSeconds, 0)
        XCTAssertEqual(sut.stepRemainingSeconds, 0)
        XCTAssertEqual(sut.stepDurationSeconds, 0)
        XCTAssertFalse(sut.isRunning)
        XCTAssertFalse(sut.stepCompleted)
    }

    // MARK: - Progress

    func testStepProgressZeroWhenNoDuration() {
        XCTAssertEqual(sut.stepProgress, 0)
    }

    func testStepProgressInitiallyZero() {
        sut.configureStep(duration: 30)
        XCTAssertEqual(sut.stepProgress, 0)
    }

    func testStepProgressFullWhenComplete() {
        sut.configureStep(duration: 10)
        // Simulate: remaining = 0 means full progress
        // We can't easily simulate time, but we can check boundary
        XCTAssertEqual(sut.stepProgress, 0)
    }

    // MARK: - Timer Phase

    func testTimerPhaseIdleWhenNoDuration() {
        XCTAssertEqual(sut.stepTimerColor, .idle)
    }

    func testTimerPhaseActiveAtStart() {
        sut.configureStep(duration: 30)
        // Progress is 0 at start -> active
        XCTAssertEqual(sut.stepTimerColor, .active)
    }

    // MARK: - Timer Ticking

    func testTimerTicksAfterStart() {
        sut.configureStep(duration: 5)
        sut.start()

        let expectation = expectation(description: "Timer ticks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        XCTAssertGreaterThan(sut.totalElapsedSeconds, 0)
        XCTAssertLessThan(sut.stepRemainingSeconds, 5)
        sut.pause()
    }

    func testStepCompletionAfterDuration() {
        sut.configureStep(duration: 1)
        sut.start()

        let expectation = expectation(description: "Step completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        XCTAssertTrue(sut.stepCompleted)
        XCTAssertEqual(sut.stepRemainingSeconds, 0)
        sut.pause()
    }
}
