import XCTest
@testable import Coffeebrew

@MainActor
final class AppEnvironmentTests: XCTestCase {

    var sut: AppEnvironment!

    override func setUp() {
        super.setUp()
        sut = AppEnvironment()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialNavigationState() {
        XCTAssertNil(sut.selectedMethod)
        XCTAssertNil(sut.selectedTechnique)
        XCTAssertNil(sut.selectedBean)
        XCTAssertEqual(sut.coffeeAmount, 15.0)
        XCTAssertEqual(sut.waterAmount, 250.0)
    }

    func testDatabaseServiceIsLoaded() {
        XCTAssertNotNil(sut.databaseService)
    }

    // MARK: - Reset

    func testResetClearsNavigationState() {
        sut.coffeeAmount = 30.0
        sut.waterAmount = 500.0

        sut.reset()

        XCTAssertNil(sut.selectedMethod)
        XCTAssertNil(sut.selectedTechnique)
        XCTAssertNil(sut.selectedBean)
        XCTAssertEqual(sut.coffeeAmount, 15.0)
        XCTAssertEqual(sut.waterAmount, 250.0)
    }

    // MARK: - Color Scheme Override

    func testColorSchemeOverrideSystem() {
        sut.appearanceMode = .system
        XCTAssertNil(sut.colorSchemeOverride)
    }

    func testColorSchemeOverrideLight() {
        sut.appearanceMode = .light
        XCTAssertEqual(sut.colorSchemeOverride, .light)
    }

    func testColorSchemeOverrideDark() {
        sut.appearanceMode = .dark
        XCTAssertEqual(sut.colorSchemeOverride, .dark)
    }

    // MARK: - AppearanceMode

    func testAppearanceModeAllCases() {
        let cases = AppearanceMode.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.system))
        XCTAssertTrue(cases.contains(.light))
        XCTAssertTrue(cases.contains(.dark))
    }

    func testAppearanceModeRawValues() {
        XCTAssertEqual(AppearanceMode.system.rawValue, "System")
        XCTAssertEqual(AppearanceMode.light.rawValue, "Light")
        XCTAssertEqual(AppearanceMode.dark.rawValue, "Dark")
    }

    func testAppearanceModeIcons() {
        XCTAssertEqual(AppearanceMode.system.icon, "circle.lefthalf.filled")
        XCTAssertEqual(AppearanceMode.light.icon, "sun.max.fill")
        XCTAssertEqual(AppearanceMode.dark.icon, "moon.fill")
    }

    func testAppearanceModeIdentifiable() {
        XCTAssertEqual(AppearanceMode.system.id, "System")
    }
}
