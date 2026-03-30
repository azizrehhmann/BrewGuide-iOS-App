import Foundation

// MARK: - Deep Dive Models

struct TechniqueDeepDive: Codable, Hashable {
    let originStory: String?
    let creator: TechniqueCreator?
    let tastingNotes: String?
    let commonMistakes: [String]
    let tips: [String]
    let videos: [TechniqueVideo]

    enum CodingKeys: String, CodingKey {
        case originStory = "origin_story"
        case creator
        case tastingNotes = "tasting_notes"
        case commonMistakes = "common_mistakes"
        case tips
        case videos
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        originStory    = try c.decodeIfPresent(String.self, forKey: .originStory)
        creator        = try c.decodeIfPresent(TechniqueCreator.self, forKey: .creator)
        tastingNotes   = try c.decodeIfPresent(String.self, forKey: .tastingNotes)
        commonMistakes = try c.decodeIfPresent([String].self, forKey: .commonMistakes) ?? []
        tips           = try c.decodeIfPresent([String].self, forKey: .tips) ?? []
        videos         = try c.decodeIfPresent([TechniqueVideo].self, forKey: .videos) ?? []
    }
}

struct TechniqueCreator: Codable, Hashable {
    let name: String
    let bio: String
    let url: String?
}

struct TechniqueVideo: Codable, Identifiable, Hashable {
    var id: String { youtubeId }
    let title: String
    let youtubeId: String
    let durationLabel: String?

    enum CodingKeys: String, CodingKey {
        case title
        case youtubeId = "youtube_id"
        case durationLabel = "duration_label"
    }

    var thumbnailURL: URL? {
        URL(string: "https://img.youtube.com/vi/\(youtubeId)/hqdefault.jpg")
    }

    var watchURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(youtubeId)")
    }
}

// MARK: - Technique

struct Technique: Codable, Identifiable, Hashable {
    let techniqueId: String
    let methodId: String
    let name: String
    let description: String
    let totalTimeSeconds: Int
    let waterTempC: Int
    let ratioWaterCoffee: Double
    let grindSizeLabel: String
    let grindSizeRef: String?
    let stepCount: Int
    let sortOrder: Int
    let deepDive: TechniqueDeepDive?

    var id: String { techniqueId }

    /// Asset catalog image name for this technique's equipment
    var imageName: String {
        let mapping: [String: String] = [
            "v60-pour-over-standard": "technique_v60",
            "v60-james-hoffmann-ultimate": "technique_v60",
            "v60-tetsu-kasuya-46-method": "technique_v60",
            "v60-matt-winton-five-pour": "technique_v60",
            "scott-rao-v60-technique": "technique_v60",
            "osmotic-flow-v60": "technique_v60",
            "chemex": "technique_chemex",
            "kalita-wave": "technique_kalita",
            "nel-drip-flannel-drip": "technique_nel_drip",
            "french-press-standard": "technique_frenchpress",
            "french-press-james-hoffmann": "technique_frenchpress",
            "clever-dripper": "technique_clever",
            "hario-switch-immersion-dripper": "technique_harioswitch",
            "cold-brew-immersion": "technique_coldbrew",
            "nitro-cold-brew": "technique_nitro",
            "cupping-professional-tasting": "technique_cupping",
            "aeropress-standardupright": "technique_aeropress",
            "aeropress-inverted-method": "technique_aeropress",
            "aeropress-wac-2025-winner-némo-pop": "technique_aeropress",
            "aeropress-wac-2024-winner-george-stanica": "technique_aeropress",
            "aeropress-james-hoffmann-best-recipe": "technique_aeropress",
            "moka-pot-stovetop-espresso": "technique_mokapot",
            "espresso-machine": "technique_espresso",
            "turkish-coffee-traditional": "technique_turkish",
            "turkish-coffee-specialty-competition": "technique_turkish",
            "cowboy-coffee": "technique_cowboy",
            "kopi-tubruk-indonesian": "technique_kopi_tubruk",
            "siphon-vacuum-brewer": "technique_siphon",
            "vietnamese-phin-filter": "technique_phin",
            "south-indian-filter-coffee-kaapi": "technique_south_indian_filter",
            "kyoto-style-slow-drip-cold-drip-tower": "technique_kyoto_tower",
            "neapolitan-flip-pot-napoletana": "technique_neapolitan_flip",
            "drip-coffee-maker-automatic": "technique_drip",
            "single-serve-pod-keurig-nespresso": "technique_pod",
            "percolator-stovetopelectric": "technique_percolator",
            "japanese-iced-coffee-flash-brew": "technique_v60",
            "melitta-pour-over-classic-flat-bottom": "technique_melitta",
        ]
        return mapping[techniqueId] ?? "technique_v60"
    }

    /// Photo asset for this technique (real brewing photo), nil if none available
    var methodPhoto: String? {
        let mapping: [String: String] = [
            "v60-pour-over-standard": "method_v60_standard",
            "v60-james-hoffmann-ultimate": "method_v60_hoffmann",
            "v60-tetsu-kasuya-46-method": "method_v60_46",
            "v60-matt-winton-five-pour": "method_v60_winton",
            "scott-rao-v60-technique": "method_v60_rao",
            "osmotic-flow-v60": "method_osmotic_flow",
            "chemex": "method_chemex",
            "kalita-wave": "method_kalita_wave",
            "nel-drip-flannel-drip": "method_nel_drip",
            "french-press-standard": "method_french_press_standard",
            "french-press-james-hoffmann": "method_french_press_hoffmann",
            "clever-dripper": "method_clever_dripper",
            "hario-switch-immersion-dripper": "method_hario_switch",
            "cold-brew-immersion": "method_cold_brew",
            "nitro-cold-brew": "method_nitro_cold_brew",
            "japanese-iced-coffee-flash-brew": "method_japanese_iced",
            "melitta-pour-over-classic-flat-bottom": "method_melitta",
        ]
        return mapping[techniqueId]
    }

    enum CodingKeys: String, CodingKey {
        case techniqueId = "technique_id"
        case methodId = "method_id"
        case name
        case description
        case totalTimeSeconds = "total_time_seconds"
        case waterTempC = "water_temp_c"
        case ratioWaterCoffee = "ratio_water_coffee"
        case grindSizeLabel = "grind_size_label"
        case grindSizeRef = "grind_size_ref"
        case stepCount = "step_count"
        case sortOrder = "sort_order"
        case deepDive = "deep_dive"
    }
}
