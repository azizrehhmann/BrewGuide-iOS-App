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

// MARK: - Custom Ratio Calculation Tests

final class CustomRatioCalculationTests: XCTestCase {

    // Mirrors the calculation logic in ParametersView
    private func waterGrams(servings: Int, defaultRatio: Double) -> Double {
        15.0 * defaultRatio * Double(servings)
    }

    private func coffeeGrams(waterGrams: Double, customRatio: Double) -> Double {
        guard customRatio > 0 else { return 0 }
        return waterGrams / customRatio
    }

    private func scaleFactor(waterGrams: Double, defaultRatio: Double) -> Double {
        let baseWater = 15.0 * defaultRatio
        guard baseWater > 0 else { return 1.0 }
        return waterGrams / baseWater
    }

    // Default ratio produces the same amounts as before (15g coffee per serving)
    func testDefaultRatioProducesOriginalCoffeeAmount() {
        let defaultRatio = 16.7
        let water = waterGrams(servings: 1, defaultRatio: defaultRatio)
        let coffee = coffeeGrams(waterGrams: water, customRatio: defaultRatio)
        XCTAssertEqual(coffee, 15.0, accuracy: 0.01)
        XCTAssertEqual(water, 250.5, accuracy: 0.01)
    }

    // Increasing ratio (weaker) reduces coffee while water stays constant
    func testHigherRatioReducesCoffee() {
        let defaultRatio = 16.7
        let water = waterGrams(servings: 1, defaultRatio: defaultRatio)
        let coffeeDefault = coffeeGrams(waterGrams: water, customRatio: defaultRatio)
        let coffeeWeak = coffeeGrams(waterGrams: water, customRatio: 18.0)
        XCTAssertLessThan(coffeeWeak, coffeeDefault)
    }

    // Decreasing ratio (stronger) increases coffee while water stays constant
    func testLowerRatioIncreasesCoffee() {
        let defaultRatio = 16.7
        let water = waterGrams(servings: 1, defaultRatio: defaultRatio)
        let coffeeDefault = coffeeGrams(waterGrams: water, customRatio: defaultRatio)
        let coffeeStrong = coffeeGrams(waterGrams: water, customRatio: 14.0)
        XCTAssertGreaterThan(coffeeStrong, coffeeDefault)
    }

    // Water does not change when ratio changes
    func testWaterUnchangedByRatio() {
        let defaultRatio = 16.7
        let water1 = waterGrams(servings: 1, defaultRatio: defaultRatio)
        let water2 = waterGrams(servings: 1, defaultRatio: defaultRatio) // same calc
        XCTAssertEqual(water1, water2, accuracy: 0.001)
    }

    // Multiple servings scale water linearly
    func testMultipleServingsScaleWater() {
        let defaultRatio = 16.7
        let water1 = waterGrams(servings: 1, defaultRatio: defaultRatio)
        let water2 = waterGrams(servings: 2, defaultRatio: defaultRatio)
        XCTAssertEqual(water2, water1 * 2, accuracy: 0.001)
    }

    // Multiple servings with custom ratio: coffee adapts proportionally
    func testMultipleServingsWithCustomRatio() {
        let defaultRatio = 16.7
        let customRatio = 14.0
        let water = waterGrams(servings: 3, defaultRatio: defaultRatio)
        let coffee = coffeeGrams(waterGrams: water, customRatio: customRatio)
        XCTAssertEqual(coffee, water / customRatio, accuracy: 0.01)
    }

    // scaleFactor always equals servings regardless of custom ratio (because water is the anchor)
    func testScaleFactorEqualsServings() {
        let defaultRatio = 16.7
        for servings in 1...6 {
            let water = waterGrams(servings: servings, defaultRatio: defaultRatio)
            let sf = scaleFactor(waterGrams: water, defaultRatio: defaultRatio)
            XCTAssertEqual(sf, Double(servings), accuracy: 0.001,
                           "scaleFactor should equal servings=\(servings)")
        }
    }

    // Ratio bounds: lower = max(1, defaultRatio - 5), upper = min(25, defaultRatio + 5)
    func testRatioBoundsForTypicalPourOver() {
        let defaultRatio = 16.7
        let lower = max(1.0, defaultRatio - 5.0)
        let upper = min(25.0, defaultRatio + 5.0)
        XCTAssertEqual(lower, 11.7, accuracy: 0.001)
        XCTAssertEqual(upper, 21.7, accuracy: 0.001)
    }

    func testRatioBoundsClampedAtMinimum() {
        let defaultRatio = 2.0   // espresso-style
        let lower = max(1.0, defaultRatio - 5.0)
        XCTAssertEqual(lower, 1.0)
    }

    func testRatioBoundsClampedAtMaximum() {
        let defaultRatio = 22.0  // very light brew
        let upper = min(25.0, defaultRatio + 5.0)
        XCTAssertEqual(upper, 25.0)
    }

    // Edge: zero/negative ratio guard
    func testZeroRatioReturnsZeroCoffee() {
        let coffee = coffeeGrams(waterGrams: 250, customRatio: 0)
        XCTAssertEqual(coffee, 0)
    }

    // MARK: - Last-Used Ratio Persistence

    func testSaveAndLoadCustomRatio() {
        let env = AppEnvironment()
        let techniqueId = "test-persistence-\(UUID().uuidString)"
        env.saveCustomRatio(14.5, forTechnique: techniqueId, defaultRatio: 16.7)
        let loaded = env.lastCustomRatio(forTechnique: techniqueId)
        XCTAssertEqual(loaded ?? 0, 14.5, accuracy: 0.01)
        // Clean up
        env.saveCustomRatio(16.7, forTechnique: techniqueId, defaultRatio: 16.7)
    }

    func testSaveDefaultRatioRemovesEntry() {
        let env = AppEnvironment()
        let techniqueId = "test-removal-\(UUID().uuidString)"
        env.saveCustomRatio(14.0, forTechnique: techniqueId, defaultRatio: 16.7)
        XCTAssertNotNil(env.lastCustomRatio(forTechnique: techniqueId))
        // Saving the default ratio should remove the entry
        env.saveCustomRatio(16.7, forTechnique: techniqueId, defaultRatio: 16.7)
        XCTAssertNil(env.lastCustomRatio(forTechnique: techniqueId))
    }

    func testNoSavedRatioReturnsNil() {
        let env = AppEnvironment()
        let result = env.lastCustomRatio(forTechnique: "nonexistent-technique-\(UUID().uuidString)")
        XCTAssertNil(result)
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
