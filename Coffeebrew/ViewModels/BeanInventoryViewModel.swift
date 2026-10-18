import CoreData
import Combine

final class BeanInventoryViewModel: ObservableObject {
    private let context: NSManagedObjectContext

    @Published var beans: [CoffeeBean] = []
    @Published var searchText: String = ""

    var filteredBeans: [CoffeeBean] {
        let active = beans.filter { $0.isActive }
        guard !searchText.isEmpty else { return active }
        let query = searchText.lowercased()
        return active.filter {
            ($0.name ?? "").lowercased().contains(query) ||
            ($0.roasterName ?? "").lowercased().contains(query) ||
            ($0.origin ?? "").lowercased().contains(query) ||
            ($0.roastLevel ?? "").lowercased().contains(query) ||
            ($0.flavourTags ?? "").lowercased().contains(query)
        }
    }

    var activeBeanCount: Int {
        beans.filter { $0.isActive }.count
    }

    init(context: NSManagedObjectContext) {
        self.context = context
        fetchBeans()
    }

    func fetchBeans() {
        let request: NSFetchRequest<CoffeeBean> = CoffeeBean.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CoffeeBean.isActive, ascending: false),
            NSSortDescriptor(keyPath: \CoffeeBean.purchaseDate, ascending: false)
        ]
        do {
            beans = try context.fetch(request)
        } catch {
            beans = []
        }
    }

    func addBean(
        name: String,
        roasterName: String,
        origin: String?,
        roastLevel: String,
        totalWeightGrams: Double,
        roastDate: Date?,
        flavourTags: String? = nil
    ) {
        let bean = CoffeeBean(context: context)
        bean.id = UUID()
        bean.name = name
        bean.roasterName = roasterName
        bean.origin = origin
        bean.roastLevel = roastLevel
        bean.flavourTags = flavourTags
        bean.totalWeightGrams = totalWeightGrams
        bean.remainingWeightGrams = totalWeightGrams
        bean.purchaseDate = Date()
        bean.roastDate = roastDate
        bean.isActive = true
        save()
        beans.insert(bean, at: 0)
    }

    func updateBean(
        _ bean: CoffeeBean,
        name: String,
        roasterName: String,
        origin: String?,
        roastLevel: String,
        totalWeightGrams: Double,
        roastDate: Date?,
        flavourTags: String? = nil
    ) {
        bean.name = name
        bean.roasterName = roasterName
        bean.origin = origin
        bean.roastLevel = roastLevel
        bean.flavourTags = flavourTags
        bean.roastDate = roastDate
        if bean.totalWeightGrams != totalWeightGrams {
            let usedGrams = bean.totalWeightGrams - bean.remainingWeightGrams
            bean.remainingWeightGrams = max(0, totalWeightGrams - usedGrams)
            bean.totalWeightGrams = totalWeightGrams
        }
        save()
        objectWillChange.send()
    }

    func deductWeight(from bean: CoffeeBean, grams: Double) {
        bean.remainingWeightGrams = max(0, bean.remainingWeightGrams - grams)
        if bean.remainingWeightGrams <= 0 {
            bean.isActive = false
        }
        save()
        objectWillChange.send()
    }

    func deleteBean(_ bean: CoffeeBean) {
        if let index = beans.firstIndex(of: bean) {
            beans.remove(at: index)
        }
        context.delete(bean)
        save()
    }

    func markEmpty(_ bean: CoffeeBean) {
        bean.remainingWeightGrams = 0
        bean.isActive = false
        save()
        objectWillChange.send()
    }

    private func save() {
        _ = context.trySave()
    }

    // MARK: - Freshness Calculations

    /// Returns the freshness window in days based on roast level.
    /// Light roasts stay fresh longer; dark roasts degrade faster.
    static func freshnessWindowDays(for roastLevel: String?) -> Int {
        switch (roastLevel ?? "Medium").lowercased() {
        case "light":        return 42  // 6 weeks
        case "medium-light": return 38  // ~5.5 weeks
        case "medium":       return 35  // 5 weeks
        case "medium-dark":  return 28  // 4 weeks
        case "dark":         return 24  // ~3.5 weeks
        default:             return 35
        }
    }

    /// Returns the peak freshness window (start and end day after roasting)
    static func peakWindow(for roastLevel: String?) -> (start: Int, end: Int) {
        switch (roastLevel ?? "Medium").lowercased() {
        case "light":        return (10, 28)
        case "medium-light": return (8, 25)
        case "medium":       return (7, 21)
        case "medium-dark":  return (5, 18)
        case "dark":         return (5, 14)
        default:             return (7, 21)
        }
    }

    /// Returns freshness fraction (1.0 = freshly roasted, 0.0 = past window) for a bean.
    static func freshnessFraction(for bean: CoffeeBean) -> Double? {
        guard let roastDate = bean.roastDate else { return nil }
        let daysSinceRoast = Calendar.current.dateComponents([.day], from: roastDate, to: Date()).day ?? 0
        let window = freshnessWindowDays(for: bean.roastLevel)
        guard window > 0 else { return 0 }
        let fraction = 1.0 - (Double(max(0, daysSinceRoast)) / Double(window))
        return max(0, min(1.0, fraction))
    }

    /// Returns a suggested "use by" date based on roast date and roast level.
    static func suggestedUseByDate(roastDate: Date, roastLevel: String?) -> Date {
        let days = freshnessWindowDays(for: roastLevel)
        return Calendar.current.date(byAdding: .day, value: days, to: roastDate) ?? roastDate
    }

    /// Human-readable freshness label
    static func freshnessLabel(for bean: CoffeeBean) -> String? {
        guard let roastDate = bean.roastDate else { return nil }
        let daysSinceRoast = Calendar.current.dateComponents([.day], from: roastDate, to: Date()).day ?? 0
        let window = freshnessWindowDays(for: bean.roastLevel)
        let peak = peakWindow(for: bean.roastLevel)

        if daysSinceRoast < 3 {
            return "Degassing"
        } else if daysSinceRoast < peak.start {
            return "Resting"
        } else if daysSinceRoast <= peak.end {
            return "Peak Fresh"
        } else if daysSinceRoast <= window {
            return "Still Good"
        } else {
            return "Past Prime"
        }
    }

    /// Freshness color
    static func freshnessColor(for bean: CoffeeBean) -> Color {
        guard let roastDate = bean.roastDate else { return .secondary }
        let daysSinceRoast = Calendar.current.dateComponents([.day], from: roastDate, to: Date()).day ?? 0
        let window = freshnessWindowDays(for: bean.roastLevel)
        let peak = peakWindow(for: bean.roastLevel)

        if daysSinceRoast < peak.start {
            return .blue     // Resting / degassing
        } else if daysSinceRoast <= peak.end {
            return .green    // Peak freshness
        } else if daysSinceRoast <= window {
            return .orange   // Still usable
        } else {
            return .red      // Past prime
        }
    }
}

import SwiftUI
