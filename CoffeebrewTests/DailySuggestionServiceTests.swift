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
}
