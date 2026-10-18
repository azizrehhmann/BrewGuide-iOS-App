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
        if sortOrder == .mostUsed {
            // Core Data can't sort by a count, so rank methods here
            let counts = Dictionary(grouping: sessions, by: { $0.equipmentName ?? "" }).mapValues(\.count)
            sessions.sort {
                let (a, b) = (counts[$0.equipmentName ?? ""] ?? 0, counts[$1.equipmentName ?? ""] ?? 0)
                return a != b ? a > b : ($0.brewedAt ?? .distantPast) > ($1.brewedAt ?? .distantPast)
            }
        }
    }

    /// Brews in the calendar week containing `now`, ignoring the search and filters.
    /// `days` starts on the calendar's first weekday, so labels and dots line up in every region.
    func thisWeek(now: Date = Date(), calendar: Calendar = .current) -> (days: [(label: String, brewed: Bool)], count: Int) {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return ([], 0) }
        let request: NSFetchRequest<BrewSession> = BrewSession.fetchRequest()
        request.predicate = NSPredicate(format: "brewedAt >= %@ AND brewedAt < %@", week.start as NSDate, week.end as NSDate)
        let brews = (try? context.fetch(request)) ?? []
        let brewedWeekdays = Set(brews.compactMap { $0.brewedAt }.map { calendar.component(.weekday, from: $0) })
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let days = (0..<7).map { offset -> (label: String, brewed: Bool) in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return (symbols[weekday - 1], brewedWeekdays.contains(weekday))
        }
        return (days, brews.count)
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
        case .mostUsed:     return [NSSortDescriptor(key: "brewedAt", ascending: false)]
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

    /// Saves a finished brew and takes the coffee out of the pantry bag it came from.
    /// Returns nil (nothing saved, nothing deducted) if the save fails.
    func recordBrew(
        technique: Technique,
        method: BrewMethod?,
        bean: Bean?,
        pantryBean: CoffeeBean?,
        servings: Int,
        coffeeGrams: Double,
        waterMl: Double,
        seconds: Int
    ) -> BrewSession? {
        let session = saveSession(
            methodName: method?.category ?? "Unknown",
            equipmentName: method?.name ?? "Unknown",
            techniqueName: technique.name,
            techniqueId: technique.techniqueId,
            beanName: pantryBean?.name ?? bean?.name,
            beanOrigin: pantryBean?.origin ?? bean?.origin,
            roastLevel: pantryBean?.roastLevel ?? bean?.roastLevel,
            servingSize: servings,
            coffeeGrams: coffeeGrams,
            waterMl: waterMl,
            grindSize: technique.grindSizeLabel,
            waterTempC: Double(technique.waterTempC),
            totalBrewTimeSeconds: seconds
        )
        guard !saveFailed else { return nil }
        if let pantryBean {
            BeanInventoryViewModel(context: context).deductWeight(from: pantryBean, grams: coffeeGrams)
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
