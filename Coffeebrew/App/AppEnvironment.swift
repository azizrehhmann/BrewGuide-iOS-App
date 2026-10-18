import SwiftUI
import Combine

final class AppEnvironment: ObservableObject {
    let databaseService: DatabaseService

    // MARK: - Navigation State
    @Published var selectedMethod: BrewMethod?
    @Published var selectedTechnique: Technique?
    @Published var selectedBean: Bean?
    @Published var coffeeAmount: Double = 15.0
    @Published var waterAmount: Double = 250.0

    // MARK: - User Preferences (persisted)
    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .system
    @AppStorage("useFahrenheit") var useFahrenheit: Bool = false
    @AppStorage("defaultServings") var defaultServings: Int = 1
    @AppStorage("autoAdvanceEnabled") var autoAdvanceEnabled: Bool = false
    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true
    @AppStorage("useFluidOunces") var useFluidOunces: Bool = false
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @AppStorage("liveActivityEnabled") var liveActivityEnabled: Bool = true
    @AppStorage("dailySuggestionNotification") var dailySuggestionNotification: Bool = false
    @AppStorage("userLevel") var userLevel: String = ""
    @AppStorage("userFlavors") var userFlavorsRaw: String = ""
    @AppStorage("userGear") var userGearRaw: String = ""
    @AppStorage("morningBrewTime") var morningBrewTime: String = "07:30"
    @AppStorage("preferredLanguage") var preferredLanguage: String = "system" {
        didSet { applyLanguage() }
    }

    /// ID of the user's selected inventory bean for the current brew
    @Published var selectedInventoryBeanID: UUID?

    /// Resolved locale to inject into the SwiftUI environment
    @Published var resolvedLocale: Locale = Locale.current

    init(databaseService: DatabaseService = DatabaseService()) {
        self.databaseService = databaseService
    }

    /// Call once on launch to apply any saved language preference
    func applyLanguageOnLaunch() {
        applyLanguage()
    }

    private func applyLanguage() {
        let code = preferredLanguage == "system"
            ? (Locale.current.language.languageCode?.identifier ?? "en")
            : preferredLanguage
        resolvedLocale = preferredLanguage == "system" ? Locale.current : Locale(identifier: preferredLanguage)
        databaseService.reload(languageCode: code)
    }

    // MARK: - Per-Technique Custom Ratio

    func saveCustomRatio(_ ratio: Double, forTechnique techniqueId: String, defaultRatio: Double) {
        var dict = customRatioDictionary
        if abs(ratio - defaultRatio) < 0.05 {
            dict.removeValue(forKey: techniqueId)
        } else {
            dict[techniqueId] = ratio
        }
        UserDefaults.standard.set(dict, forKey: "lastCustomRatios")
    }

    func lastCustomRatio(forTechnique techniqueId: String) -> Double? {
        customRatioDictionary[techniqueId]
    }

    private var customRatioDictionary: [String: Double] {
        UserDefaults.standard.dictionary(forKey: "lastCustomRatios") as? [String: Double] ?? [:]
    }

    func reset() {
        selectedMethod = nil
        selectedTechnique = nil
        selectedBean = nil
        selectedInventoryBeanID = nil
        coffeeAmount = 15.0
        waterAmount = 250.0
    }

    var colorSchemeOverride: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}
