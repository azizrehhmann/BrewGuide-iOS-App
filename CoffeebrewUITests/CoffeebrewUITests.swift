import XCTest

final class CoffeebrewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-hasSeenOnboarding", "true"]
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    private func button(containing label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
    }

    // MARK: - Tabs

    func testTabsSwitchBetweenRootScreens() {
        app.launch()
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 8))

        app.buttons["Library"].tap()
        XCTAssertTrue(app.textFields["Search techniques"].waitForExistence(timeout: 3), "Library search field")

        app.buttons["Pantry"].tap()
        XCTAssertTrue(app.staticTexts["Pantry"].waitForExistence(timeout: 3))

        app.buttons["Journal"].tap()
        // Empty journal shows "No brews yet"; a journal with entries shows the week card
        XCTAssertTrue(app.staticTexts["No brews yet"].waitForExistence(timeout: 3) || app.staticTexts["THIS WEEK"].waitForExistence(timeout: 3))

        app.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
    }

    // MARK: - Settings

    func testSettingsOpensAndCloses() {
        app.launch()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8), "Settings must be reachable from Today")
        settings.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Appearance"].exists)
        XCTAssertTrue(app.staticTexts["Units"].exists)

        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 3))
    }

    // MARK: - Brew flow

    func testBeginBrewingReachesTimerScreen() {
        app.launch()
        let begin = button(containing: "Begin brewing")
        XCTAssertTrue(begin.waitForExistence(timeout: 8))
        begin.tap()

        // Bean selection, then parameters, then the brew itself. The bottom buttons must be tappable
        // without the tab bar covering them.
        let toParameters = button(containing: "Continue")
        XCTAssertTrue(toParameters.waitForExistence(timeout: 5))
        XCTAssertTrue(toParameters.isHittable, "Continue must not sit under the tab bar")
        toParameters.tap()

        let start = button(containing: "Begin brewing")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        if !start.isHittable { app.swipeUp() }
        start.tap()

        XCTAssertTrue(app.buttons["Close brew session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Next step"].exists)
    }

    func testBrewFromLibraryEndsInJournalWithRatingAndBean() {
        app.launch()
        app.buttons["Library"].tap()
        XCTAssertTrue(app.textFields["Search techniques"].waitForExistence(timeout: 8))
        // No typing: the simulator's first-run keyboard tip would cover the tab bar
        app.buttons["Pressure"].tap()  // AeroPress – James Hoffmann has the shortest recipe (6 steps)

        let card = button(containing: "James Hoffmann")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let toParameters = app.buttons["Continue to brewing parameters"]
        XCTAssertTrue(toParameters.waitForExistence(timeout: 5))
        toParameters.tap()
        let start = button(containing: "Begin brewing")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        if !start.isHittable { app.swipeUp() }
        start.tap()

        for _ in 0..<5 {
            let next = app.buttons["Next step"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }
        let complete = app.buttons["Complete brew"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()

        let fiveStars = app.buttons["5 stars"]
        XCTAssertTrue(fiveStars.waitForExistence(timeout: 5))
        fiveStars.tap()
        button(containing: "Save to journal").tap()

        // The brew screens close and Library is back, not stuck on Brew Complete
        XCTAssertTrue(app.textFields["Search techniques"].waitForExistence(timeout: 5))
        app.buttons["Journal"].tap()
        // Each entry card is one button whose label includes "with <bean>"
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS ' with '")).firstMatch.waitForExistence(timeout: 5),
                      "The journal entry should name the bean")
    }

    // MARK: - Onboarding

    func testOnboardingCompletesAndShowsToday() {
        app.launchArguments = ["-hasSeenOnboarding", "false"]
        app.launch()

        let begin = button(containing: "Begin")
        XCTAssertTrue(begin.waitForExistence(timeout: 8))
        begin.tap()

        // Walk the steps, making the selections that enable Continue.
        for _ in 0..<8 {
            if app.buttons["Enter Kōhi"].waitForExistence(timeout: 1) {
                app.buttons["Enter Kōhi"].tap()
                break
            }
            if button(containing: "Curious").exists { button(containing: "Curious").tap() }
            if button(containing: "Floral").exists { button(containing: "Floral").tap() }
            let skip = button(containing: "Skip for now")
            if skip.exists { skip.tap(); continue }
            let next = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Continue'")).firstMatch
            if next.waitForExistence(timeout: 2) && next.isEnabled { next.tap() }
        }

        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 8), "Today should appear after onboarding")
    }
}
