import CoreData
import Combine
import SwiftUI

final class BrewJournalViewModel: ObservableObject {
    @Published var sessions: [BrewSession] = []
    @Published var searchText: String = ""
    @Published var filterRating: Int = 0
    @Published var filterFavourites: Bool = false
    @Published var sortOrder: SortOrder = .newest
    /// True if the most recent save failed; callers check it right after a write.
    @Published private(set) var saveFailed = false

    enum SortOrder: String, CaseIterable {
        case newest = "Newest first"
        case oldest = "Oldest first"
        case highestRated = "Highest rated"
        case mostUsed = "Most used method"
    }

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        fetchSessions()
    }

    // MARK: - Fetch

    func fetchSessions() {
        let request: NSFetchRequest<BrewSession> = BrewSession.fetchRequest()
        request.predicate = buildPredicate()
        request.sortDescriptors = buildSortDescriptors()
        do {
            sessions = try context.fetch(request)
        } catch {
            print("Fetch error: \(error)")
        }
    }

    private func buildPredicate() -> NSCompoundPredicate {
        var predicates: [NSPredicate] = []
        if !searchText.isEmpty {
            predicates.append(NSPredicate(
                format: "techniqueName CONTAINS[cd] %@ OR equipmentName CONTAINS[cd] %@ OR beanName CONTAINS[cd] %@ OR notes CONTAINS[cd] %@",
                searchText, searchText, searchText, searchText
            ))
        }
        if filterRating > 0 {
            predicates.append(NSPredicate(format: "rating >= %d", filterRating))
        }
        if filterFavourites {
            predicates.append(NSPredicate(format: "isFavourite == YES"))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func buildSortDescriptors() -> [NSSortDescriptor] {
        switch sortOrder {
        case .newest:       return [NSSortDescriptor(key: "brewedAt", ascending: false)]
        case .oldest:       return [NSSortDescriptor(key: "brewedAt", ascending: true)]
        case .highestRated: return [NSSortDescriptor(key: "rating", ascending: false),
                                    NSSortDescriptor(key: "brewedAt", ascending: false)]
        case .mostUsed:     return [NSSortDescriptor(key: "techniqueName", ascending: true),
                                    NSSortDescriptor(key: "brewedAt", ascending: false)]
        }
    }

    // MARK: - Save

    @discardableResult
    func saveSession(
        methodName: String,
        equipmentName: String,
        techniqueName: String,
        techniqueId: String? = nil,
        beanName: String?,
        beanOrigin: String?,
        roastLevel: String?,
        servingSize: Int,
        coffeeGrams: Double,
        waterMl: Double,
        grindSize: String,
        waterTempC: Double,
        totalBrewTimeSeconds: Int
    ) -> BrewSession {
        let session = BrewSession(context: context)
        session.id = UUID()
        session.brewedAt = Date()
        session.methodName = methodName
        session.equipmentName = equipmentName
        session.techniqueName = techniqueName
        session.techniqueId = techniqueId
        session.beanName = beanName
        session.beanOrigin = beanOrigin
        session.roastLevel = roastLevel
        session.servingSize = Int16(servingSize)
        session.coffeeAmountGrams = coffeeGrams
        session.waterAmountMl = waterMl
        session.grindSize = grindSize
        session.waterTempC = waterTempC
        session.totalBrewTimeSeconds = Int32(totalBrewTimeSeconds)
        session.rating = 0
        session.isFavourite = false
        if save() {
            // Insert at the beginning (newest first) instead of full refetch
            sessions.insert(session, at: 0)
        } else {
            // Drop the unsaved object so a retry doesn't save a duplicate
            context.delete(session)
        }
        return session
    }

    // MARK: - Update

    func updateRating(_ rating: Int, for session: BrewSession) {
        session.rating = Int16(rating)
        save()
        // Session is already in the array; @Published update via objectWillChange
        objectWillChange.send()
    }

    func updateNotes(_ notes: String, for session: BrewSession) {
        session.notes = notes.isEmpty ? nil : notes
        save()
        objectWillChange.send()
    }

    func updateFlavourTags(_ tags: [String], for session: BrewSession) {
        session.flavourTags = tags.isEmpty ? nil : tags.joined(separator: ",")
        save()
        objectWillChange.send()
    }

    func toggleFavourite(_ session: BrewSession) {
        session.isFavourite.toggle()
        save()
        // If filtering by favourites, we need a full refetch; otherwise just notify
        if filterFavourites {
            fetchSessions()
        } else {
            objectWillChange.send()
        }
    }

    // MARK: - Delete

    func delete(_ session: BrewSession) {
        if let index = sessions.firstIndex(of: session) {
            sessions.remove(at: index)
        }
        context.delete(session)
        save()
    }

    func deleteAll() {
        sessions.forEach { context.delete($0) }
        sessions.removeAll()
        save()
    }

    // MARK: - Helpers

    @discardableResult
    private func save() -> Bool {
        let ok = context.trySave()
        saveFailed = !ok
        return ok
    }

    var totalBrews: Int { sessions.count }

    var averageRating: Double {
        let rated = sessions.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return Double(rated.map { Int($0.rating) }.reduce(0, +)) / Double(rated.count)
    }

    var mostBrewedMethod: String? {
        let counts = Dictionary(grouping: sessions, by: \.methodName)
            .mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var flavourTags: [String] {
        Array(Set(sessions
            .compactMap(\.flavourTags)
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        )).sorted()
    }
}
