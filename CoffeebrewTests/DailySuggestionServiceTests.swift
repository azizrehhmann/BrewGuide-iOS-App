import XCTest
import CoreData
@testable import Coffeebrew

final class DailySuggestionServiceTests: XCTestCase {
    private let lastDateKey = "dailySuggestion_streakLastDate"
    private let countKey = "dailySuggestion_streakCount"
    private var sut: DailySuggestionService!

    @MainActor
    override func setUp() {
        super.setUp()
        let context = PersistenceController(inMemory: true).container.viewContext
        sut = DailySuggestionService(databaseService: DatabaseService(), context: context)
        clearStreak()
    }

    override func tearDown() {
        clearStreak()
        sut = nil
        super.tearDown()
    }

    private func clearStreak() {
        UserDefaults.standard.removeObject(forKey: lastDateKey)
        UserDefaults.standard.removeObject(forKey: countKey)
    }

    private func seedStreak(daysAgo: Int, count: Int) {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Calendar.current.startOfDay(for: Date()))!
        UserDefaults.standard.set(day, forKey: lastDateKey)
        UserDefaults.standard.set(count, forKey: countKey)
    }

    private var streak: Int { UserDefaults.standard.integer(forKey: countKey) }

    func testFirstBrewStartsStreakAtOne() {
        sut.recordSuggestionBrew()
        XCTAssertEqual(streak, 1)
    }

    func testBrewingTwiceSameDayDoesNotIncrement() {
        sut.recordSuggestionBrew()
        sut.recordSuggestionBrew()
        XCTAssertEqual(streak, 1)
    }

    func testBrewingDayAfterIncrements() {
        seedStreak(daysAgo: 1, count: 2)
        sut.recordSuggestionBrew()
        XCTAssertEqual(streak, 3)
    }

    func testMissedDayResetsStreak() {
        seedStreak(daysAgo: 3, count: 5)
        sut.recordSuggestionBrew()
        XCTAssertEqual(streak, 1)
    }

    @MainActor
    func testRefreshProducesSuggestionFromEmptyHistory() {
        sut.refreshIfNeeded()
        XCTAssertNotNil(sut.suggestion)
        XCTAssertFalse(sut.suggestion?.hasPreviousBrew ?? true)
    }

    // MARK: - Seasons (0 spring, 1 summer, 2 autumn, 3 winter)

    private func date(month: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: 15))!
    }

    func testSeasonNorthernHemisphere() {
        XCTAssertEqual(DailySuggestionService.currentSeason(for: date(month: 1), region: "DE"), 3)
        XCTAssertEqual(DailySuggestionService.currentSeason(for: date(month: 7), region: "DE"), 1)
    }

    func testSeasonSouthernHemisphereIsFlipped() {
        XCTAssertEqual(DailySuggestionService.currentSeason(for: date(month: 1), region: "AU"), 1)
        XCTAssertEqual(DailySuggestionService.currentSeason(for: date(month: 7), region: "AU"), 3)
        XCTAssertEqual(DailySuggestionService.currentSeason(for: date(month: 9), region: "AU"), 0)
    }
}
