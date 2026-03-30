import Foundation
import FoundationModels

/// A user-facing bean profile used for AI recommendation.
/// Can be created from inventory (CoffeeBean), scanned bag, or manual entry.
struct BeanProfile: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var roaster: String?
    var origin: String?
    var region: String?
    var process: String?
    var roastLevel: String?
    var flavourNotes: [String]
    var altitude: String?
    var variety: String?

    /// Concise text description sent to the on-device LLM
    var aiDescription: String {
        var parts: [String] = []
        parts.append("Name: \(name)")
        if let roaster { parts.append("Roaster: \(roaster)") }
        if let origin { parts.append("Origin: \(origin)") }
        if let region { parts.append("Region: \(region)") }
        if let process { parts.append("Process: \(process)") }
        if let roastLevel { parts.append("Roast: \(roastLevel)") }
        if !flavourNotes.isEmpty { parts.append("Flavour notes: \(flavourNotes.joined(separator: ", "))") }
        if let altitude { parts.append("Altitude: \(altitude)") }
        if let variety { parts.append("Variety: \(variety)") }
        return parts.joined(separator: "\n")
    }

    /// Create from a Core Data inventory bean
    init(from coffeeBean: CoffeeBean) {
        self.name = coffeeBean.name ?? "Unknown"
        self.roaster = coffeeBean.roasterName
        self.origin = coffeeBean.origin
        self.roastLevel = coffeeBean.roastLevel
        self.flavourNotes = []
    }

    /// Create from scanned bag data
    init(from scanned: ScannedBeanData) {
        self.name = scanned.name
        self.roaster = scanned.roaster
        self.origin = scanned.origin
        self.region = scanned.region
        self.process = scanned.process
        self.roastLevel = scanned.roastLevel
        self.flavourNotes = scanned.flavourNotes
        self.altitude = scanned.altitude
        self.variety = scanned.variety
    }

    /// Manual entry
    init(
        name: String,
        roaster: String? = nil,
        origin: String? = nil,
        region: String? = nil,
        process: String? = nil,
        roastLevel: String? = nil,
        flavourNotes: [String] = [],
        altitude: String? = nil,
        variety: String? = nil
    ) {
        self.name = name
        self.roaster = roaster
        self.origin = origin
        self.region = region
        self.process = process
        self.roastLevel = roastLevel
        self.flavourNotes = flavourNotes
        self.altitude = altitude
        self.variety = variety
    }
}

// MARK: - Scanned Bean Data (on-device LLM output)

@Generable
struct ScannedBeanData {
    @Guide(description: "Full bean name including roaster if visible, e.g. 'Square Mile Red Brick'")
    var name: String

    @Guide(description: "Roaster name only, if clearly stated on the label")
    var roaster: String?

    @Guide(description: "Country of origin, e.g. 'Ethiopia'")
    var origin: String?

    @Guide(description: "Specific region or farm, e.g. 'Yirgacheffe'")
    var region: String?

    @Guide(description: "Processing method: Washed, Natural, Honey, or Other")
    var process: String?

    @Guide(description: "Roast level: Light, Medium-Light, Medium, Medium-Dark, or Dark")
    var roastLevel: String?

    @Guide(description: "Flavour descriptors listed on the bag, e.g. ['Blueberry', 'Jasmine']")
    var flavourNotes: [String]

    @Guide(description: "Growing altitude if stated, e.g. '1800-2200m'")
    var altitude: String?

    @Guide(description: "Coffee variety if stated, e.g. 'Heirloom' or 'Bourbon'")
    var variety: String?
}
