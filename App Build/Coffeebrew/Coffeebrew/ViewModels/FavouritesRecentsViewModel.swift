import Combine
import CoreData
import SwiftUI

/// Provides favourite and recently brewed techniques for the HomeView.
/// Queries BrewSession Core Data and maps back to Technique objects.
final class FavouritesRecentsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var favouriteTechniques: [TechniqueQuickBrew] = []
    @Published var recentTechniques: [TechniqueQuickBrew] = []

    private let context: NSManagedObjectContext
    private let databaseService: DatabaseService

    // MARK: - Quick Brew Model

    struct TechniqueQuickBrew: Identifiable, Hashable {
        let id: String  // techniqueId
        let technique: Technique
        let method: BrewMethod
        let lastBrewedAt: Date
        let brewCount: Int
        let lastCoffeeGrams: Double
        let lastWaterMl: Double
        let lastServingSize: Int
        let isFavourite: Bool

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: TechniqueQuickBrew, rhs: TechniqueQuickBrew) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Init

    init(context: NSManagedObjectContext, databaseService: DatabaseService) {
        self.context = context
        self.databaseService = databaseService
        refresh()
    }

    // MARK: - Refresh

    func refresh() {
        fetchFavourites()
        fetchRecents()
    }

    // MARK: - Favourites

    /// Techniques from sessions marked as favourite, grouped by technique, most recent first
    private func fetchFavourites() {
        let request: NSFetchRequest<BrewSession> = BrewSession.fetchRequest()
        request.predicate = NSPredicate(format: "isFavourite == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "brewedAt", ascending: false)]

        guard let sessions = try? context.fetch(request) else { return }

        // Group by technique name, take the most recent session per technique
        let grouped = Dictionary(grouping: sessions) { $0.techniqueName ?? "" }
        var items: [TechniqueQuickBrew] = []

        for (name, techSessions) in grouped {
            guard !name.isEmpty,
                  let latest = techSessions.first,
                  let technique = resolveTechnique(from: latest),
                  let method = databaseService.method(byId: technique.methodId)
            else { continue }

            items.append(TechniqueQuickBrew(
                id: technique.techniqueId,
                technique: technique,
                method: method,
                lastBrewedAt: latest.brewedAt ?? Date(),
                brewCount: techSessions.count,
                lastCoffeeGrams: latest.coffeeAmountGrams,
                lastWaterMl: latest.waterAmountMl,
                lastServingSize: Int(latest.servingSize),
                isFavourite: true
            ))
        }

        favouriteTechniques = items.sorted { $0.lastBrewedAt > $1.lastBrewedAt }
    }

    // MARK: - Recents

    /// Most recently brewed techniques (excluding favourites already shown), max 8
    private func fetchRecents() {
        let request: NSFetchRequest<BrewSession> = BrewSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "brewedAt", ascending: false)]
        request.fetchLimit = 100  // enough to find unique techniques

        guard let sessions = try? context.fetch(request) else { return }

        // Pre-compute technique IDs for all sessions to avoid O(n²) repeated lookups
        let resolvedSessions: [(session: BrewSession, techniqueId: String, technique: Technique)] = sessions.compactMap { session in
            guard let technique = resolveTechnique(from: session) else { return nil }
            return (session, technique.techniqueId, technique)
        }

        // Count brews per technique in one pass
        var brewCounts: [String: Int] = [:]
        for item in resolvedSessions {
            brewCounts[item.techniqueId, default: 0] += 1
        }

        let favouriteIds = Set(favouriteTechniques.map(\.id))
        var seen = Set<String>()
        var items: [TechniqueQuickBrew] = []

        for item in resolvedSessions {
            let technique = item.technique
            guard let method = databaseService.method(byId: technique.methodId),
                  !favouriteIds.contains(technique.techniqueId),
                  !seen.contains(technique.techniqueId)
            else { continue }

            seen.insert(technique.techniqueId)

            items.append(TechniqueQuickBrew(
                id: technique.techniqueId,
                technique: technique,
                method: method,
                lastBrewedAt: item.session.brewedAt ?? Date(),
                brewCount: brewCounts[technique.techniqueId] ?? 1,
                lastCoffeeGrams: item.session.coffeeAmountGrams,
                lastWaterMl: item.session.waterAmountMl,
                lastServingSize: Int(item.session.servingSize),
                isFavourite: item.session.isFavourite
            ))

            if items.count >= 8 { break }
        }

        recentTechniques = items
    }

    // MARK: - Toggle Favourite

    func toggleFavourite(techniqueId: String) {
        let request: NSFetchRequest<BrewSession> = BrewSession.fetchRequest()

        // Match by techniqueId if available, fallback to name
        if let technique = databaseService.technique(byId: techniqueId) {
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "techniqueId == %@", techniqueId),
                NSPredicate(format: "techniqueName == %@", technique.name)
            ])
        } else {
            request.predicate = NSPredicate(format: "techniqueId == %@", techniqueId)
        }

        guard let sessions = try? context.fetch(request), !sessions.isEmpty else { return }

        // Toggle: if ANY session is favourite, unfavourite all; otherwise favourite all
        let anyFav = sessions.contains { $0.isFavourite }
        for session in sessions {
            session.isFavourite = !anyFav
        }

        if let coordinator = context.persistentStoreCoordinator,
           !coordinator.persistentStores.isEmpty {
            try? context.save()
        }
        refresh()
    }

    // MARK: - Helpers

    /// Resolve a BrewSession to a Technique using techniqueId first, then name fallback
    private func resolveTechnique(from session: BrewSession) -> Technique? {
        if let techId = session.techniqueId,
           let technique = databaseService.technique(byId: techId) {
            return technique
        }
        // Fallback: match by name
        if let name = session.techniqueName {
            return databaseService.techniques.first { $0.name == name }
        }
        return nil
    }

    private func resolveTechniqueId(from session: BrewSession) -> String? {
        resolveTechnique(from: session)?.techniqueId
    }

    var hasContent: Bool {
        !favouriteTechniques.isEmpty || !recentTechniques.isEmpty
    }
}
