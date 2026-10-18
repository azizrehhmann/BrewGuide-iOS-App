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
    // Kept as Double so sub-second time survives pause/resume
    private var accumulatedTotal: TimeInterval = 0
    private var accumulatedStep: TimeInterval = 0

    var stepProgress: Double {
        guard stepDurationSeconds > 0 else { return 0 }
        let elapsed = stepDurationSeconds - stepRemainingSeconds
        return min(1.0, Double(elapsed) / Double(stepDurationSeconds))
    }

    // MARK: - Controls

    func configureStep(duration: Int) {
        pause()
        stepDurationSeconds = duration
        stepRemainingSeconds = duration
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
        if let startDate {
            let delta = Date().timeIntervalSince(startDate)
            accumulatedTotal += delta
            accumulatedStep += delta
            totalElapsedSeconds = Int(accumulatedTotal)
            if stepDurationSeconds > 0 {
                stepRemainingSeconds = max(0, stepDurationSeconds - Int(accumulatedStep))
            }
        }
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
        accumulatedStep = 0
        stepCompleted = false
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    // MARK: - Tick

    private func tick() {
        guard let startDate else { return }
        let delta = Date().timeIntervalSince(startDate)

        // Update total elapsed
        totalElapsedSeconds = Int(accumulatedTotal + delta)

        // Update step countdown
        if stepDurationSeconds > 0 {
            stepRemainingSeconds = max(0, stepDurationSeconds - Int(accumulatedStep + delta))

            if stepRemainingSeconds == 0, !stepCompleted {
                stepCompleted = true
            }
        }
    }
}
