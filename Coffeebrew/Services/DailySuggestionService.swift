import Combine
import CoreData
import Foundation
import UserNotifications

final class DailySuggestionService: ObservableObject {

    // MARK: - Published state

    @Published private(set) var suggestion: DailySuggestion?
    @Published private(set) var isLoading = false

    // MARK: - Dependencies

    private let databaseService: DatabaseService
    private let context: NSManagedObjectContext

    // MARK: - Cache keys

    private enum Keys {
        static let cachedTechniqueId = "dailySuggestion_techniqueId"
        static let cachedDate = "dailySuggestion_date"
        static let streakLastDate = "dailySuggestion_streakLastDate"
        static let streakCount = "dailySuggestion_streakCount"
    }

    // MARK: - Seasonal weights per technique

    /// [spring, summer, autumn, winter] multipliers
    private static let seasonalWeights: [String: [Double]] = [
        "cold-brew-immersion": [0.6, 1.4, 0.8, 0.4],
        "nitro-cold-brew": [0.6, 1.4, 0.7, 0.3],
        "kyoto-style-slow-drip-cold-drip-tower": [0.7, 1.3, 0.8, 0.5],
        "japanese-iced-coffee-flash-brew": [0.8, 1.4, 0.8, 0.5],
        "siphon-vacuum-brewer": [1.0, 0.8, 1.1, 1.3],
        "turkish-coffee-traditional": [0.9, 0.7, 1.1, 1.3],
        "turkish-coffee-specialty-competition": [0.9, 0.7, 1.1, 1.3],
        "moka-pot-stovetop-espresso": [1.0, 0.8, 1.1, 1.2],
        "cowboy-coffee": [0.8, 0.9, 1.2, 1.2],
        "french-press-standard": [1.0, 0.9, 1.1, 1.1],
        "french-press-james-hoffmann": [1.0, 0.9, 1.1, 1.1],
        "espresso-machine": [1.0, 1.0, 1.0, 1.0],
    ]

    /// Flavour hooks per technique (evocative one-liners)
    private static let flavourHooks: [String: String] = [
        "v60-pour-over-standard": "Clean & nuanced",
        "v60-james-hoffmann-ultimate": "Bright & transparent",
        "v60-tetsu-kasuya-46-method": "Balanced sweetness",
        "v60-matt-winton-five-pour": "Structured clarity",
        "scott-rao-v60-technique": "Even extraction",
        "osmotic-flow-v60": "Silky & delicate",
        "chemex": "Crisp & sparkling",
        "kalita-wave": "Smooth & forgiving",
        "nel-drip-flannel-drip": "Velvety body",
        "french-press-standard": "Rich & full-bodied",
        "french-press-james-hoffmann": "Clean immersion",
        "clever-dripper": "Sweet & balanced",
        "hario-switch-immersion-dripper": "Hybrid clarity",
        "cold-brew-immersion": "Smooth & mellow",
        "nitro-cold-brew": "Creamy & refreshing",
        "cupping-professional-tasting": "Pure origin flavour",
        "aeropress-standardupright": "Concentrated & versatile",
        "aeropress-inverted-method": "Bold & full",
        "aeropress-wac-2025-winner-némo-pop": "Competition precision",
        "aeropress-wac-2024-winner-george-stanica": "Championship clarity",
        "aeropress-james-hoffmann-best-recipe": "Approachable & clean",
        "moka-pot-stovetop-espresso": "Intense & aromatic",
        "espresso-machine": "Concentrated punch",
        "turkish-coffee-traditional": "Thick & spiced",
        "turkish-coffee-specialty-competition": "Refined tradition",
        "cowboy-coffee": "Rustic & bold",
        "kopi-tubruk-indonesian": "Earthy & sweet",
        "siphon-vacuum-brewer": "Tea-like clarity",
        "vietnamese-phin-filter": "Sweet & strong",
        "south-indian-filter-coffee-kaapi": "Chicory warmth",
        "kyoto-style-slow-drip-cold-drip-tower": "Delicate cold extraction",
        "neapolitan-flip-pot-napoletana": "Old-world charm",
        "drip-coffee-maker-automatic": "Consistent & easy",
        "single-serve-pod-keurig-nespresso": "Quick convenience",
        "percolator-stovetopelectric": "Strong & classic",
        "japanese-iced-coffee-flash-brew": "Bright & icy",
        "melitta-pour-over-classic-flat-bottom": "Gentle & sweet",
    ]

    // MARK: - Init

    init(databaseService: DatabaseService, context: NSManagedObjectContext) {
        self.databaseService = databaseService
        self.context = context
    }

    // MARK: - Public API

    /// Recompute if the cached date doesn't match today. Safe to call repeatedly.
    func refreshIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())

        if let cached = loadCachedDate(), Calendar.current.isDate(cached, inSameDayAs: today),
           let cachedId = UserDefaults.standard.string(forKey: Keys.cachedTechniqueId),
           suggestion?.technique.techniqueId == cachedId {
            return // cache is fresh
        }

        recompute(for: today)
    }

    /// Force a full recompute (e.g. after midnight)
    func forceRefresh() {
        let today = Calendar.current.startOfDay(for: Date())
        recompute(for: today)
    }

    /// Record that the user tapped "Brew now" on today's suggestion card
    func recordSuggestionBrew() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = UserDefaults.standard.object(forKey: Keys.streakLastDate) as? Date
        var streak = UserDefaults.standard.integer(forKey: Keys.streakCount)

        if let last = lastDate {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
            if Calendar.current.isDate(last, inSameDayAs: yesterday) {
                streak += 1
            } else if !Calendar.current.isDate(last, inSameDayAs: today) {
                streak = 1
            }
            // same day → no change
        } else {
            streak = 1
        }

        UserDefaults.standard.set(today, forKey: Keys.streakLastDate)
        UserDefaults.standard.set(streak, forKey: Keys.streakCount)

        // Update the current suggestion's streak
        if var s = suggestion {
            suggestion = DailySuggestion(
                technique: s.technique,
                method: s.method,
                computedDate: s.computedDate,
                personalScore: s.personalScore,
                reasonLabel: s.reasonLabel,
                streakDays: streak,
                hasPreviousBrew: s.hasPreviousBrew,
                previousBestRating: s.previousBestRating,
                flavourHook: s.flavourHook
            )
        }
    }

    // MARK: - Notification scheduling

    /// Schedules (or cancels) a repeating reminder. Text is generic because a repeating
    /// notification can't carry each day's technique. `time` is "HH:mm".
    static func scheduleDailyNotification(enabled: Bool, time: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["dailySuggestion"])

        guard enabled else { return }

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Today's brew is ready"
            content.body = "Open BrewGuide to see today's suggestion"
            content.sound = .default
            content.userInfo = ["url": "brewguide://suggestion"]

            let parts = time.split(separator: ":").compactMap { Int($0) }
            var dateComponents = DateComponents()
            dateComponents.hour = parts.first ?? 8
            dateComponents.minute = parts.count > 1 ? parts[1] : 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            center.add(UNNotificationRequest(identifier: "dailySuggestion", content: content, trigger: trigger))
        }
    }

    // MARK: - Private: Algorithm Pipeline

    private func recompute(for today: Date) {
        isLoading = true

        let allTechniques = databaseService.techniques
            .sorted { $0.techniqueId < $1.techniqueId } // stable sort for deterministic seed
        let total = allTechniques.count
        guard total > 0 else {
            isLoading = false
            return
        }

        // Stage 1 — Daily seed
        let epoch = Calendar.current.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: today).day ?? 0
        let seedIndex = epoch % total

        // Stage 2 — Candidate window (5 techniques around seed)
        var candidateIndices: [Int] = []
        for offset in -2...2 {
            candidateIndices.append((seedIndex + offset + total) % total)
        }
        var candidates = candidateIndices.map { allTechniques[$0] }

        // Stage 3 — Recency filter
        let recentTechniqueNames = fetchRecentBrewTechniqueNames(within: 14)
        let filtered = candidates.filter { !recentTechniqueNames.contains($0.name) }

        if !filtered.isEmpty {
            candidates = filtered
        }
        // If all filtered out, keep original candidates (fallback to global pick)

        // Stage 4 — Score and rank
        let brewHistory = fetchBrewHistory()
        let mostBrewedDifficulty = computeMostBrewedDifficulty(from: brewHistory)
        let yesterdayCategory = fetchYesterdayCategory()
        let triedTechniqueNames = Set(brewHistory.map(\.techniqueName))
        let currentSeason = Self.currentSeason(for: today)
        let totalBrews = brewHistory.count

        var bestCandidate = candidates[0]
        var bestScore = Double.leastNormalMagnitude
        var bestReason = ""

        for candidate in candidates {
            var score: Double = 0
            let method = databaseService.method(byId: candidate.methodId)
            let difficulty = method?.difficulty ?? 3

            // Difficulty match (+30)
            if difficulty == mostBrewedDifficulty {
                score += 30
            }

            // Method diversity (+25)
            if let cat = method?.category, cat != yesterdayCategory {
                score += 25
            }

            // Seasonal fit (+20)
            let weights = Self.seasonalWeights[candidate.techniqueId] ?? [1.0, 1.0, 1.0, 1.0]
            score += 20 * weights[currentSeason]

            // Not tried before (+15)
            if !triedTechniqueNames.contains(candidate.name) {
                score += 15
            }

            // High journal rating (+10) / Poor rating (-20)
            let ratings = brewHistory
                .filter { $0.techniqueName == candidate.name }
                .compactMap { $0.rating > 0 ? Int($0.rating) : nil }

            if let bestRating = ratings.max() {
                if bestRating >= 4 { score += 10 }
                if bestRating <= 2 { score -= 20 }
            }

            // Brewed recently (-40)
            if recentTechniqueNames.contains(candidate.name) {
                score -= 40
            }

            // Beginner boost: prefer easier techniques for new users
            if totalBrews < 5 && difficulty <= 2 {
                score += 10
            }

            if score > bestScore {
                bestScore = score
                bestCandidate = candidate

                // Build reason label
                if !triedTechniqueNames.contains(candidate.name) {
                    bestReason = "Try something new today"
                } else if let cat = method?.category, cat != yesterdayCategory {
                    bestReason = "Switch it up — explore \(cat.lowercased())"
                } else {
                    bestReason = "A great pick for today"
                }
            }
        }

        // Stage 5 — Cache result
        UserDefaults.standard.set(bestCandidate.techniqueId, forKey: Keys.cachedTechniqueId)
        UserDefaults.standard.set(today, forKey: Keys.cachedDate)

        // Compute streak
        let streak = computeCurrentStreak(today: today)

        // Previous brew info
        let previousBrews = brewHistory.filter { $0.techniqueName == bestCandidate.name }
        let hasPrevious = !previousBrews.isEmpty
        let bestRating = previousBrews
            .compactMap { $0.rating > 0 ? Int($0.rating) : nil }
            .max()

        let method = databaseService.method(byId: bestCandidate.methodId)
            ?? BrewMethod(methodId: "", name: "Unknown", description: "", difficulty: 3,
                          iconName: "cup.and.saucer", imageName: nil, category: "Other")

        let flavour = Self.flavourHooks[bestCandidate.techniqueId] ?? "A unique brew experience"

        // Normalize score to 0–1
        let maxPossible: Double = 30 + 25 + 20 * 1.4 + 15 + 10 // ~108
        let normalizedScore = max(0, min(1, bestScore / maxPossible))

        suggestion = DailySuggestion(
            technique: bestCandidate,
            method: method,
            computedDate: today,
            personalScore: normalizedScore,
            reasonLabel: bestReason,
            streakDays: streak,
            hasPreviousBrew: hasPrevious,
            previousBestRating: bestRating,
            flavourHook: flavour
        )

        isLoading = false
    }

    // MARK: - CoreData Queries

    private struct BrewRecord {
        let techniqueName: String
        let equipmentName: String
        let rating: Int16
        let brewedAt: Date
    }

    private func fetchBrewHistory() -> [BrewRecord] {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "BrewSession")
        request.propertiesToFetch = ["techniqueName", "equipmentName", "rating", "brewedAt"]
        request.resultType = .dictionaryResultType

        do {
            let results = try context.fetch(request) as? [[String: Any]] ?? []
            return results.compactMap { dict in
                guard let name = dict["techniqueName"] as? String,
                      let date = dict["brewedAt"] as? Date else { return nil }
                let rating = dict["rating"] as? Int16 ?? 0
                let equipment = dict["equipmentName"] as? String ?? ""
                return BrewRecord(techniqueName: name, equipmentName: equipment, rating: rating, brewedAt: date)
            }
        } catch {
            return []
        }
    }

    private func fetchRecentBrewTechniqueNames(within days: Int) -> Set<String> {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "BrewSession")
        request.predicate = NSPredicate(format: "brewedAt >= %@", cutoff as NSDate)
        request.propertiesToFetch = ["techniqueName"]
        request.resultType = .dictionaryResultType

        do {
            let results = try context.fetch(request) as? [[String: Any]] ?? []
            return Set(results.compactMap { $0["techniqueName"] as? String })
        } catch {
            return []
        }
    }

    private func fetchYesterdayCategory() -> String? {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return nil }
        let dayStart = Calendar.current.startOfDay(for: yesterday)
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else { return nil }

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "BrewSession")
        request.predicate = NSPredicate(format: "brewedAt >= %@ AND brewedAt < %@",
                                        dayStart as NSDate, dayEnd as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "brewedAt", ascending: false)]
        request.fetchLimit = 1
        request.propertiesToFetch = ["equipmentName"]
        request.resultType = .dictionaryResultType

        do {
            let results = try context.fetch(request) as? [[String: Any]] ?? []
            if let equipmentName = results.first?["equipmentName"] as? String {
                return databaseService.method(byName: equipmentName)?.category
            }
        } catch {}
        return nil
    }

    private func computeMostBrewedDifficulty(from history: [BrewRecord]) -> Int {
        var difficultyCount: [Int: Int] = [:]
        for record in history {
            if let method = databaseService.method(byName: record.equipmentName) {
                difficultyCount[method.difficulty, default: 0] += 1
            }
        }
        return difficultyCount.max(by: { $0.value < $1.value })?.key ?? 3
    }

    private func computeCurrentStreak(today: Date) -> Int {
        guard let lastDate = UserDefaults.standard.object(forKey: Keys.streakLastDate) as? Date else {
            return 0
        }
        let streak = UserDefaults.standard.integer(forKey: Keys.streakCount)

        // Streak is valid if last brew was today or yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        if Calendar.current.isDate(lastDate, inSameDayAs: today) ||
           Calendar.current.isDate(lastDate, inSameDayAs: yesterday) {
            return streak
        }
        // Streak broken
        UserDefaults.standard.set(0, forKey: Keys.streakCount)
        return 0
    }

    // MARK: - Cache

    private func loadCachedDate() -> Date? {
        UserDefaults.standard.object(forKey: Keys.cachedDate) as? Date
    }

    // MARK: - Helpers

    // shortcut: country list is approximate (Indonesia/Peru straddle the equator); extend if needed
    private static let southernRegions: Set<String> = ["AU", "NZ", "AR", "CL", "UY", "PY", "BO", "ZA", "BR"]

    static func currentSeason(for date: Date, region: String? = Locale.current.region?.identifier) -> Int {
        var month = Calendar.current.component(.month, from: date)
        if let region, southernRegions.contains(region) { month = (month + 5) % 12 + 1 }
        switch month {
        case 3, 4, 5: return 0   // spring
        case 6, 7, 8: return 1   // summer
        case 9, 10, 11: return 2 // autumn
        default: return 3        // winter
        }
    }

    static func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes < 1 { return "<1 min" }
        return "~\(minutes) min"
    }
}
