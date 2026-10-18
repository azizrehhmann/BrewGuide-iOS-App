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
}
