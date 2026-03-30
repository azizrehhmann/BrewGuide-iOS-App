import Foundation

struct GrindSize: Codable, Identifiable {
    let level: String
    let texture: String
    let particleSizeUm: String
    let particleMinUm: Int
    let particleMaxUm: Int
    let comandanteClicks: String
    let comandanteMin: Int
    let comandanteMax: Int
    let ek43Range: String
    let ek43Min: Double
    let ek43Max: Double

    var id: String { level }

    enum CodingKeys: String, CodingKey {
        case level
        case texture
        case particleSizeUm = "particle_size_um"
        case particleMinUm = "particle_min_um"
        case particleMaxUm = "particle_max_um"
        case comandanteClicks = "comandante_clicks"
        case comandanteMin = "comandante_min"
        case comandanteMax = "comandante_max"
        case ek43Range = "ek43_range"
        case ek43Min = "ek43_min"
        case ek43Max = "ek43_max"
    }
}
