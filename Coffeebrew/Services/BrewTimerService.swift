import Foundation
import Combine

final class BrewTimerService: ObservableObject {
    // MARK: - Global elapsed timer (total brew time)
    @Published var totalElapsedSeconds: Int = 0

    // MARK: - Per-step countdown
    @Published var stepRemainingSeconds: Int = 0
    @Published var stepDurationSeconds: Int = 0
    @Published var isRunning: Bool = false
    @Published var stepCompleted: Bool = false

    private var timer: AnyCancellable?
    private var startDate: Date?
    private var accumulatedTotal: Int = 0
    private var accumulatedStep: Int = 0
    private var stepElapsed: Int = 0

    var stepProgress: Double {
        guard stepDurationSeconds > 0 else { return 0 }
        let elapsed = stepDurationSeconds - stepRemainingSeconds
        return min(1.0, Double(elapsed) / Double(stepDurationSeconds))
    }

    var stepTimerColor: TimerPhase {
        guard stepDurationSeconds > 0 else { return .idle }
        let fraction = stepProgress
        if fraction >= 0.9 { return .ending }
        if fraction >= 0.6 { return .warning }
        return .active
    }

    enum TimerPhase {
        case idle, active, warning, ending
    }

    // MARK: - Controls

    func configureStep(duration: Int) {
        pause()
        stepDurationSeconds = duration
        stepRemainingSeconds = duration
        stepElapsed = 0
        accumulatedStep = 0
        stepCompleted = false
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        stepCompleted = false
        startDate = Date()
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func pause() {
        guard isRunning else { return }
        accumulatedTotal = totalElapsedSeconds
        accumulatedStep = stepElapsed
        isRunning = false
        startDate = nil
        timer?.cancel()
        timer = nil
    }

    func reset() {
        pause()
        totalElapsedSeconds = 0
        accumulatedTotal = 0
        stepRemainingSeconds = 0
        stepDurationSeconds = 0
        stepElapsed = 0
        accumulatedStep = 0
        stepCompleted = false
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    // MARK: - Tick

    private func tick() {
        guard let startDate else { return }
        let delta = Int(Date().timeIntervalSince(startDate))

        // Update total elapsed
        totalElapsedSeconds = accumulatedTotal + delta

        // Update step countdown
        if stepDurationSeconds > 0 {
            stepElapsed = accumulatedStep + delta
            stepRemainingSeconds = max(0, stepDurationSeconds - stepElapsed)

            if stepRemainingSeconds == 0, !stepCompleted {
                stepCompleted = true
            }
        }
    }
}
