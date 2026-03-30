import XCTest

final class CoffeebrewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Reset onboarding state for predictable test runs
        app.launchArguments = ["-hasSeenOnboarding", "true"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Home Screen

    func testHomeScreenShowsBrewGuideTitle() {
        let title = app.staticTexts["BrewGuide"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "BrewGuide title should be visible on home screen")
    }

    func testHomeScreenShowsBrewingMethodsHeader() {
        let header = app.staticTexts["Brewing Methods"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Brewing Methods header should be visible")
    }

    func testSettingsButtonExists() {
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should exist")
    }

    // MARK: - Settings

    func testOpenAndCloseSettings() {
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3), "Settings screen should appear")

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button should exist")
        doneButton.tap()

        // Should return to home
        let title = app.staticTexts["BrewGuide"]
        XCTAssertTrue(title.waitForExistence(timeout: 3), "Should return to home after dismissing settings")
    }

    func testSettingsShowsAllSections() {
        app.buttons["Settings"].tap()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 3))

        // Check section headers exist
        XCTAssertTrue(app.staticTexts["Appearance"].exists, "Appearance section should exist")
        XCTAssertTrue(app.staticTexts["Units"].exists, "Units section should exist")
        XCTAssertTrue(app.staticTexts["Brewing Defaults"].exists, "Brewing Defaults section should exist")
        XCTAssertTrue(app.staticTexts["Accessibility"].exists, "Accessibility section should exist")
        // Scroll to About
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["About"].waitForExistence(timeout: 2), "About section should exist")

        app.buttons["Done"].tap()
    }

    // MARK: - Navigation Flow

    func testTapMethodCardNavigatesToTechniques() {
        // Wait for cards to load
        let brewingMethods = app.staticTexts["Brewing Methods"]
        XCTAssertTrue(brewingMethods.waitForExistence(timeout: 5))

        // Tap the first method card (look for any button with accessibility hint)
        let firstCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'difficulty'")).firstMatch
        guard firstCard.waitForExistence(timeout: 5) else {
            XCTFail("No method card found")
            return
        }
        firstCard.tap()

        // Should show a navigation bar (technique list)
        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 3), "Should navigate to technique list with back button")
    }

    // MARK: - Onboarding

    func testOnboardingFlowShownOnFirstLaunch() {
        // Launch fresh without skipping onboarding
        let freshApp = XCUIApplication()
        freshApp.launchArguments = ["-hasSeenOnboarding", "false"]
        freshApp.launch()

        let welcomeText = freshApp.staticTexts["Welcome to BrewGuide"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5), "Onboarding should show on first launch")

        // Tap Next twice then Get Started
        let nextButton = freshApp.buttons["Next page"]
        if nextButton.waitForExistence(timeout: 3) {
            nextButton.tap()

            let nextButton2 = freshApp.buttons["Next page"]
            if nextButton2.waitForExistence(timeout: 3) {
                nextButton2.tap()
            }

            let getStarted = freshApp.buttons["Get started with BrewGuide"]
            if getStarted.waitForExistence(timeout: 3) {
                getStarted.tap()
            }
        }

        // After onboarding, home should appear
        let title = freshApp.staticTexts["BrewGuide"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Home screen should appear after onboarding")
    }
}
