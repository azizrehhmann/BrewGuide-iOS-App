import XCTest
import CoreData
@testable import Coffeebrew

final class BrewJournalViewModelTests: XCTestCase {
    var context: NSManagedObjectContext!
    var sut: BrewJournalViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        context = PersistenceController(inMemory: true).container.viewContext
        sut = BrewJournalViewModel(context: context)
    }

    override func tearDown() {
        sut = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Record brew

    @MainActor
    func testRecordBrewUsesPantryBeanAndDeductsCoffee() {
        let db = DatabaseService()
        let technique = db.techniques[0]
        let inventory = BeanInventoryViewModel(context: context)
        inventory.addBean(name: "Pantry Bean", roasterName: "Roaster", origin: "Kenya", roastLevel: "Light",
                          totalWeightGrams: 30, roastDate: nil)
        let pantry = inventory.beans[0]

        let session = sut.recordBrew(
            technique: technique, method: db.method(byId: technique.methodId),
            bean: db.beans[0], pantryBean: pantry,
            servings: 1, coffeeGrams: 15, waterMl: 250, seconds: 200
        )
        XCTAssertEqual(session?.beanName, "Pantry Bean")
        XCTAssertEqual(session?.beanOrigin, "Kenya")
        XCTAssertEqual(pantry.remainingWeightGrams, 15, accuracy: 0.01)
    }

    @MainActor
    func testRecordBrewFallsBackToRecommendedBean() {
        let db = DatabaseService()
        let technique = db.techniques[0]
        let session = sut.recordBrew(
            technique: technique, method: nil, bean: db.beans[0], pantryBean: nil,
            servings: 1, coffeeGrams: 15, waterMl: 250, seconds: 200
        )
        XCTAssertEqual(session?.beanName, db.beans[0].name)
    }

    // MARK: - Week and sort

    @MainActor
    func testThisWeekLabelsStartOnFirstWeekday() {
        var us = Calendar(identifier: .gregorian)
        us.firstWeekday = 1  // Sunday
        let monday = us.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 9))!
        let session = sut.saveSession(
            methodName: "m", equipmentName: "e", techniqueName: "t", beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250, grindSize: "Medium", waterTempC: 93, totalBrewTimeSeconds: 1
        )
        session.brewedAt = monday

        let week = sut.thisWeek(now: monday, calendar: us)
        XCTAssertEqual(week.count, 1)
        XCTAssertEqual(week.days.map(\.brewed), [false, true, false, false, false, false, false])
        XCTAssertEqual(week.days[1].label, "M")
    }

    @MainActor
    func testMostUsedSortPutsTheMostBrewedMethodFirst() {
        for (equipment, minutesAgo) in [("AeroPress", 1), ("V60", 2), ("V60", 3)] {
            let session = sut.saveSession(
                methodName: "m", equipmentName: equipment, techniqueName: "t", beanName: nil, beanOrigin: nil, roastLevel: nil,
                servingSize: 1, coffeeGrams: 15, waterMl: 250, grindSize: "Medium", waterTempC: 93, totalBrewTimeSeconds: 1
            )
            session.brewedAt = Date().addingTimeInterval(Double(-minutesAgo * 60))
        }
        sut.sortOrder = .mostUsed
        sut.fetchSessions()
        XCTAssertEqual(sut.sessions.map { $0.equipmentName ?? "" }, ["V60", "V60", "AeroPress"])
    }

    // MARK: - Save

    @MainActor
    func testSaveSessionPersistsRecord() async {
        _ = sut.saveSession(
            methodName: "Pour Over", equipmentName: "V60", techniqueName: "Standard",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 2, coffeeGrams: 30, waterMl: 500,
            grindSize: "Medium", waterTempC: 94, totalBrewTimeSeconds: 240
        )
        XCTAssertEqual(sut.sessions.count, 1)
        XCTAssertEqual(sut.sessions.first?.techniqueName, "Standard")
    }

    @MainActor
    func testSaveSessionSetsCorrectValues() async {
        let session = sut.saveSession(
            methodName: "Immersion", equipmentName: "French Press", techniqueName: "Hoffmann",
            beanName: "Ethiopia Sidamo", beanOrigin: "Ethiopia", roastLevel: "Light",
            servingSize: 3, coffeeGrams: 45, waterMl: 750,
            grindSize: "Coarse", waterTempC: 92, totalBrewTimeSeconds: 480
        )
        XCTAssertEqual(session.methodName, "Immersion")
        XCTAssertEqual(session.equipmentName, "French Press")
        XCTAssertEqual(session.beanName, "Ethiopia Sidamo")
        XCTAssertEqual(session.coffeeAmountGrams, 45, accuracy: 0.01)
        XCTAssertEqual(session.waterAmountMl, 750, accuracy: 0.01)
        XCTAssertEqual(session.servingSize, 3)
        XCTAssertEqual(session.rating, 0)
        XCTAssertFalse(session.isFavourite)
    }

    // MARK: - Update Rating

    @MainActor
    func testUpdateRatingUpdatesValue() async {
        let session = sut.saveSession(
            methodName: "French Press", equipmentName: "French Press", techniqueName: "Hoffmann",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "Coarse", waterTempC: 92, totalBrewTimeSeconds: 480
        )
        sut.updateRating(4, for: session)
        XCTAssertEqual(sut.sessions.first?.rating, 4)
    }

    // MARK: - Update Notes

    @MainActor
    func testUpdateNotesUpdatesValue() async {
        let session = sut.saveSession(
            methodName: "Pour Over", equipmentName: "V60", techniqueName: "Standard",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "Medium", waterTempC: 94, totalBrewTimeSeconds: 240
        )
        sut.updateNotes("Bright and fruity", for: session)
        XCTAssertEqual(session.notes, "Bright and fruity")
    }

    @MainActor
    func testUpdateNotesEmptyClearsNotes() async {
        let session = sut.saveSession(
            methodName: "Pour Over", equipmentName: "V60", techniqueName: "Standard",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "Medium", waterTempC: 94, totalBrewTimeSeconds: 240
        )
        sut.updateNotes("Some note", for: session)
        sut.updateNotes("", for: session)
        XCTAssertNil(session.notes)
    }

    // MARK: - Delete

    @MainActor
    func testDeleteRemovesSession() async {
        let session = sut.saveSession(
            methodName: "AeroPress", equipmentName: "AeroPress", techniqueName: "Inverted",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 18, waterMl: 200,
            grindSize: "Medium-Fine", waterTempC: 85, totalBrewTimeSeconds: 120
        )
        sut.delete(session)
        XCTAssertTrue(sut.sessions.isEmpty)
    }

    @MainActor
    func testDeleteAllClearsSessions() async {
        _ = sut.saveSession(
            methodName: "A", equipmentName: "A", techniqueName: "A",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        _ = sut.saveSession(
            methodName: "B", equipmentName: "B", techniqueName: "B",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        sut.deleteAll()
        XCTAssertTrue(sut.sessions.isEmpty)
    }

    // MARK: - Toggle Favourite

    @MainActor
    func testToggleFavouriteTogglesBool() async {
        let session = sut.saveSession(
            methodName: "Pour Over", equipmentName: "V60", techniqueName: "Standard",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "Medium", waterTempC: 94, totalBrewTimeSeconds: 240
        )
        XCTAssertFalse(session.isFavourite)
        sut.toggleFavourite(session)
        XCTAssertTrue(session.isFavourite)
        sut.toggleFavourite(session)
        XCTAssertFalse(session.isFavourite)
    }

    // MARK: - Filter Favourites

    @MainActor
    func testFilterFavouritesReturnsOnlyFavourites() async {
        let s1 = sut.saveSession(
            methodName: "A", equipmentName: "A", techniqueName: "A",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        _ = sut.saveSession(
            methodName: "B", equipmentName: "B", techniqueName: "B",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        sut.toggleFavourite(s1)
        sut.filterFavourites = true
        sut.fetchSessions()
        XCTAssertEqual(sut.sessions.count, 1)
        XCTAssertTrue(sut.sessions.first?.isFavourite == true)
    }

    // MARK: - Average Rating

    @MainActor
    func testAverageRatingCalculatesCorrectly() async {
        let s1 = sut.saveSession(
            methodName: "A", equipmentName: "A", techniqueName: "A",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        let s2 = sut.saveSession(
            methodName: "B", equipmentName: "B", techniqueName: "B",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        sut.updateRating(4, for: s1)
        sut.updateRating(2, for: s2)
        XCTAssertEqual(sut.averageRating, 3.0, accuracy: 0.01)
    }

    @MainActor
    func testAverageRatingIgnoresUnrated() async {
        let s1 = sut.saveSession(
            methodName: "A", equipmentName: "A", techniqueName: "A",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        _ = sut.saveSession(
            methodName: "B", equipmentName: "B", techniqueName: "B",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        sut.updateRating(5, for: s1)
        // s2 stays at 0 (unrated)
        XCTAssertEqual(sut.averageRating, 5.0, accuracy: 0.01)
    }

    // MARK: - Most Brewed

    @MainActor
    func testMostBrewedMethodReturnsCorrectMethod() async {
        _ = sut.saveSession(
            methodName: "Pour Over", equipmentName: "V60", techniqueName: "Standard",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        _ = sut.saveSession(
            methodName: "Pour Over", equipmentName: "V60", techniqueName: "Hoffmann",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        _ = sut.saveSession(
            methodName: "Immersion", equipmentName: "French Press", techniqueName: "Standard FP",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        XCTAssertEqual(sut.mostBrewedMethod, "Pour Over")
    }

    // MARK: - Flavour Tags

    @MainActor
    func testFlavourTagsAggregatesUniqueTags() async {
        let s1 = sut.saveSession(
            methodName: "A", equipmentName: "A", techniqueName: "A",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        let s2 = sut.saveSession(
            methodName: "B", equipmentName: "B", techniqueName: "B",
            beanName: nil, beanOrigin: nil, roastLevel: nil,
            servingSize: 1, coffeeGrams: 15, waterMl: 250,
            grindSize: "M", waterTempC: 93, totalBrewTimeSeconds: 200
        )
        sut.updateFlavourTags(["Fruity", "Bright"], for: s1)
        sut.updateFlavourTags(["Bright", "Sweet"], for: s2)
        sut.fetchSessions()
        let tags = sut.flavourTags
        XCTAssertEqual(tags.count, 3)
        XCTAssertTrue(tags.contains("Fruity"))
        XCTAssertTrue(tags.contains("Bright"))
        XCTAssertTrue(tags.contains("Sweet"))
    }
}

// MARK: - Inventory deduction

final class BeanInventoryViewModelTests: XCTestCase {
    @MainActor
    func testDeductWeightMarksBeanInactiveAtZero() {
        let context = PersistenceController(inMemory: true).container.viewContext
        let sut = BeanInventoryViewModel(context: context)
        sut.addBean(name: "Test", roasterName: "Roaster", origin: nil, roastLevel: "Medium",
                    totalWeightGrams: 30, roastDate: nil)
        let bean = sut.beans[0]

        sut.deductWeight(from: bean, grams: 20)
        XCTAssertEqual(bean.remainingWeightGrams, 10, accuracy: 0.01)
        XCTAssertTrue(bean.isActive)

        sut.deductWeight(from: bean, grams: 20)
        XCTAssertEqual(bean.remainingWeightGrams, 0, accuracy: 0.01)
        XCTAssertFalse(bean.isActive)
    }

    @MainActor
    func testAddBeanReportsFailedSaveAndKeepsListClean() {
        // A container with no stores can't save
        let container = NSPersistentContainer(name: "BrewGuide", managedObjectModel: PersistenceController(inMemory: true).container.managedObjectModel)
        let sut = BeanInventoryViewModel(context: container.viewContext)
        sut.addBean(name: "Lost", roasterName: "R", origin: nil, roastLevel: "Medium",
                    totalWeightGrams: 250, roastDate: nil)
        XCTAssertTrue(sut.saveFailed)
        XCTAssertTrue(sut.beans.isEmpty)
    }
}
