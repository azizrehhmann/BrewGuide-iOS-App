import Foundation

final class DatabaseService {
    private(set) var methods: [BrewMethod] = []
    private(set) var techniques: [Technique] = []
    private(set) var steps: [BrewStep] = []
    private(set) var beans: [Bean] = []
    private(set) var grindSizes: [GrindSize] = []

    // MARK: - Indexed Lookups (O(1) instead of O(n))

    private var methodById: [String: BrewMethod] = [:]
    private var techniqueById: [String: Technique] = [:]
    private var techniquesByMethodId: [String: [Technique]] = [:]
    private var stepsByTechniqueId: [String: [BrewStep]] = [:]
    private var beansByTechniqueId: [String: [Bean]] = [:]
    private var grindSizeByLevel: [String: GrindSize] = [:]
    private var methodsByCategory: [String: [BrewMethod]] = [:]
    private var methodByName: [String: BrewMethod] = [:]

    // MARK: - Cached Computed Properties

    private var _categories: [String]?
    private var _allTechniquesWithMethod: [(technique: Technique, method: BrewMethod)]?

    private var isLoaded = false
    private var loadedLanguageCode: String = "en"

    init() {
        loadAll()
    }

    // MARK: - Loading

    func loadAll() {
        guard !isLoaded else { return }
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        loadAll(languageCode: code)
    }

    func reload(languageCode: String) {
        guard languageCode != loadedLanguageCode else { return }
        isLoaded = false
        loadAll(languageCode: languageCode)
    }

    private func loadAll(languageCode: String) {
        guard !isLoaded else { return }
        loadedLanguageCode = languageCode
        methods = load("methods", languageCode: languageCode)
        techniques = load("techniques", languageCode: languageCode)
        steps = load("steps", languageCode: languageCode)
        beans = load("beans", languageCode: languageCode)
        grindSizes = load("grind_sizes", languageCode: languageCode)
        buildIndices()
        isLoaded = true
    }

    private func load<T: Decodable>(_ filename: String) -> [T] {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        return load(filename, languageCode: languageCode)
    }

    private func load<T: Decodable>(_ filename: String, languageCode: String) -> [T] {
        // Try locale-specific file first (e.g. methods_ja, steps_de, beans_fr)
        if languageCode != "en" {
            let localizedName = "\(filename)_\(languageCode)"
            if let url = Bundle.main.url(forResource: localizedName, withExtension: "json") {
                do {
                    let data = try Data(contentsOf: url)
                    return try JSONDecoder().decode([T].self, from: data)
                } catch {
                    print("DatabaseService: Failed to decode \(localizedName).json — \(error), falling back to English")
                }
            }
        }

        // Fall back to English base file
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("DatabaseService: \(filename).json not found in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            print("DatabaseService: Failed to decode \(filename).json — \(error)")
            return []
        }
    }

    /// Build all dictionary indices after loading data
    private func buildIndices() {
        // Method lookups
        methodById = Dictionary(methods.map { ($0.methodId, $0) }, uniquingKeysWith: { first, _ in first })
        methodsByCategory = Dictionary(grouping: methods, by: \.category)
        methodByName = Dictionary(methods.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        // Technique lookups
        techniqueById = Dictionary(techniques.map { ($0.techniqueId, $0) }, uniquingKeysWith: { first, _ in first })
        techniquesByMethodId = Dictionary(grouping: techniques, by: \.methodId)
            .mapValues { $0.sorted { $0.sortOrder < $1.sortOrder } }

        // Steps lookup (pre-sorted)
        stepsByTechniqueId = Dictionary(grouping: steps, by: \.techniqueId)
            .mapValues { $0.sorted { $0.stepNumber < $1.stepNumber } }

        // Beans lookup (pre-sorted)
        beansByTechniqueId = Dictionary(grouping: beans, by: \.techniqueId)
            .mapValues { $0.sorted { $0.matchScore > $1.matchScore } }

        // Grind size lookup
        grindSizeByLevel = Dictionary(grindSizes.map { ($0.level, $0) }, uniquingKeysWith: { first, _ in first })

        // Pre-compute categories
        let order = ["Pour Over", "Immersion", "Pressure", "Cold Brew", "Stovetop & Traditional", "Machine"]
        let found = Set(methods.map(\.category))
        _categories = order.filter { found.contains($0) }

        // Pre-compute allTechniquesWithMethod
        _allTechniquesWithMethod = techniques.compactMap { technique in
            guard let method = methodById[technique.methodId] else { return nil }
            return (technique, method)
        }
        .sorted { $0.technique.name < $1.technique.name }
    }

    // MARK: - Queries (O(1) dictionary lookups)

    func techniques(forMethodId methodId: String) -> [Technique] {
        techniquesByMethodId[methodId] ?? []
    }

    func steps(forTechniqueId techniqueId: String) -> [BrewStep] {
        stepsByTechniqueId[techniqueId] ?? []
    }

    func beans(forTechniqueId techniqueId: String) -> [Bean] {
        beansByTechniqueId[techniqueId] ?? []
    }

    func method(byId methodId: String) -> BrewMethod? {
        methodById[methodId]
    }

    func technique(byId techniqueId: String) -> Technique? {
        techniqueById[techniqueId]
    }

    /// Unique category names in display order
    var categories: [String] {
        _categories ?? []
    }

    func methods(forCategory category: String) -> [BrewMethod] {
        methodsByCategory[category] ?? []
    }

    /// All techniques paired with their parent method, sorted alphabetically
    var allTechniquesWithMethod: [(technique: Technique, method: BrewMethod)] {
        _allTechniquesWithMethod ?? []
    }

    func grindSize(forLevel level: String) -> GrindSize? {
        grindSizeByLevel[level]
    }

    func method(byName name: String) -> BrewMethod? {
        methodByName[name]
    }
}
