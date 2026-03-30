import Foundation

struct BrewMethod: Codable, Identifiable, Hashable {
    let methodId: String
    let name: String
    let description: String
    let difficulty: Int
    let iconName: String
    let imageName: String?
    let category: String

    var id: String { methodId }

    enum CodingKeys: String, CodingKey {
        case methodId = "method_id"
        case name
        case description
        case difficulty
        case iconName = "icon_name"
        case imageName = "image_name"
        case category
    }

    /// Asset catalog image name for this method's equipment
    var techniqueImageName: String {
        let mapping: [String: String] = [
            "v60-pour-over": "technique_v60",
            "chemex": "technique_chemex",
            "kalita-wave": "technique_kalita",
            "nel-drip": "technique_nel_drip",
            "french-press": "technique_frenchpress",
            "clever-dripper": "technique_clever",
            "hario-switch": "technique_harioswitch",
            "cold-brew": "technique_coldbrew",
            "japanese-iced": "technique_v60",
            "aeropress": "technique_aeropress",
            "moka-pot": "technique_mokapot",
            "espresso": "technique_espresso",
            "turkish-coffee": "technique_turkish",
            "cowboy-coffee": "technique_cowboy",
            "kopi-tubruk": "technique_kopi_tubruk",
            "siphon": "technique_siphon",
            "vietnamese-phin": "technique_phin",
            "south-indian-filter": "technique_south_indian_filter",
            "kyoto-cold-drip": "technique_kyoto_tower",
            "neapolitan-flip": "technique_neapolitan_flip",
            "drip-machine": "technique_drip",
            "percolator": "technique_percolator",
            "cupping": "technique_cupping",
            "melitta-pour-over": "technique_melitta",
        ]
        return mapping[methodId] ?? "technique_v60"
    }

    var difficultyLabel: String {
        switch difficulty {
        case 1: return String(localized: "Beginner")
        case 2: return String(localized: "Easy")
        case 3: return String(localized: "Intermediate")
        case 4: return String(localized: "Advanced")
        case 5: return String(localized: "Expert")
        default: return String(localized: "Unknown")
        }
    }
}
