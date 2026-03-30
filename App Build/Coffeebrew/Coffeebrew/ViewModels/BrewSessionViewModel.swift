import SwiftUI
import Combine

final class BrewSessionViewModel: ObservableObject {
    @Published var technique: Technique?
    @Published var steps: [BrewStep] = []
    @Published var currentStepIndex: Int = 0
    @Published var selectedBean: Bean?
    @Published var coffeeGrams: Double = 15
    @Published var waterGrams: Double = 250

    private var databaseService: DatabaseService?

    var currentStep: BrewStep? {
        guard currentStepIndex >= 0, currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    var isLastStep: Bool {
        currentStepIndex >= steps.count - 1
    }

    var progress: Double {
        guard steps.count > 0 else { return 0 }
        return Double(currentStepIndex + 1) / Double(steps.count)
    }

    func configure(technique: Technique, service: DatabaseService) {
        self.technique = technique
        self.databaseService = service
        self.steps = service.steps(forTechniqueId: technique.techniqueId)
        self.currentStepIndex = 0
        self.coffeeGrams = 15
        self.waterGrams = 15 * technique.ratioWaterCoffee
    }

    func nextStep() {
        guard currentStepIndex < steps.count - 1 else { return }
        currentStepIndex += 1
    }

    func previousStep() {
        guard currentStepIndex > 0 else { return }
        currentStepIndex -= 1
    }

    func reset() {
        currentStepIndex = 0
    }
}
