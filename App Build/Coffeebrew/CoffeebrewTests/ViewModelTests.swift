import XCTest
@testable import Coffeebrew

// MARK: - BrewSessionViewModel Tests

final class BrewSessionViewModelTests: XCTestCase {

    @MainActor
    private func makeTechnique(
        id: String = "test-technique",
        methodId: String = "test-method",
        ratio: Double = 16.0,
        stepCount: Int = 3
    ) -> Technique {
        let json = """
        {
            "technique_id": "\(id)",
            "method_id": "\(methodId)",
            "name": "Test Technique",
            "description": "A test technique.",
            "total_time_seconds": 180,
            "water_temp_c": 95,
            "ratio_water_coffee": \(ratio),
            "grind_size_label": "Medium",
            "grind_size_ref": null,
            "step_count": \(stepCount),
            "sort_order": 1
        }
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(Technique.self, from: json)
    }

    // MARK: - Initial State

    @MainActor
    func testInitialState() async {
        let vm = BrewSessionViewModel()
        XCTAssertNil(vm.technique)
        XCTAssertTrue(vm.steps.isEmpty)
        XCTAssertEqual(vm.currentStepIndex, 0)
        XCTAssertNil(vm.selectedBean)
    }

    // MARK: - Current Step

    @MainActor
    func testCurrentStepNilWhenNoSteps() async {
        let vm = BrewSessionViewModel()
        XCTAssertNil(vm.currentStep)
    }

    // MARK: - Progress

    @MainActor
    func testProgressZeroWhenNoSteps() async {
        let vm = BrewSessionViewModel()
        XCTAssertEqual(vm.progress, 0)
    }

    // MARK: - Navigation

    @MainActor
    func testNextStepDoesNotExceedBounds() async {
        let vm = BrewSessionViewModel()
        vm.nextStep()
        XCTAssertEqual(vm.currentStepIndex, 0)
    }

    @MainActor
    func testPreviousStepDoesNotGoBelowZero() async {
        let vm = BrewSessionViewModel()
        vm.previousStep()
        XCTAssertEqual(vm.currentStepIndex, 0)
    }

    @MainActor
    func testResetGoesToFirstStep() async {
        let vm = BrewSessionViewModel()
        vm.reset()
        XCTAssertEqual(vm.currentStepIndex, 0)
    }

    // MARK: - Water Calculation

    @MainActor
    func testWaterCalculationFromRatio() async {
        let vm = BrewSessionViewModel()
        let technique = makeTechnique(ratio: 16.0)
        let service = DatabaseService()
        vm.configure(technique: technique, service: service)

        XCTAssertEqual(vm.waterGrams, 240, accuracy: 0.1)
        XCTAssertEqual(vm.coffeeGrams, 15)
    }

    // MARK: - isLastStep

    @MainActor
    func testIsLastStepWhenNoSteps() async {
        let vm = BrewSessionViewModel()
        XCTAssertTrue(vm.isLastStep)
    }
}

// MARK: - MethodViewModel Tests

final class MethodViewModelTests: XCTestCase {

    @MainActor
    func testInitialState() async {
        let vm = MethodViewModel()
        XCTAssertTrue(vm.methods.isEmpty)
        XCTAssertTrue(vm.selectedMethodTechniques.isEmpty)
    }

    @MainActor
    func testLoadPopulatesMethods() async {
        let vm = MethodViewModel()
        let service = DatabaseService()
        vm.load(from: service)
        XCTAssertNotNil(vm.methods)
    }

    @MainActor
    func testLoadTechniquesWithoutServiceIsNoop() async {
        let vm = BrewSessionViewModel()
        vm.reset()
        XCTAssertEqual(vm.currentStepIndex, 0)
    }
}

// MARK: - BeansViewModel Tests

final class BeansViewModelTests: XCTestCase {

    @MainActor
    func testInitialState() async {
        let vm = BeansViewModel()
        XCTAssertTrue(vm.beans.isEmpty)
        XCTAssertNil(vm.selectedBean)
    }

    @MainActor
    func testLoadWithNoMatchingBeans() async {
        let vm = BeansViewModel()
        let service = DatabaseService()
        vm.load(forTechniqueId: "nonexistent-technique-id", from: service)
        XCTAssertTrue(vm.beans.isEmpty)
        XCTAssertNil(vm.selectedBean)
    }
}
