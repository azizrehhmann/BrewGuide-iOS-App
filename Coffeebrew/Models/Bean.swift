import Foundation

struct Bean: Codable, Identifiable, Hashable {
    let beanId: String
    let techniqueId: String
    let name: String
    let origin: String
    let process: String
    let roastLevel: String
    let flavourNotes: [String]
    let matchScore: Int
    let notes: String?

    var id: String { beanId }

    enum CodingKeys: String, CodingKey {
        case beanId = "bean_id"
        case techniqueId = "technique_id"
        case name
        case origin
        case process
        case roastLevel = "roast_level"
        case flavourNotes = "flavour_notes"
        case matchScore = "match_score"
        case notes
    }
}
