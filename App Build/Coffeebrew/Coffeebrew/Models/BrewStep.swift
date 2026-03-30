import Foundation

struct BrewStep: Codable, Identifiable, Hashable {
    let stepId: String
    let techniqueId: String
    let stepNumber: Int
    let title: String
    let instruction: String
    let durationSeconds: Int
    let waterVolumeMlBase: Double
    let imageName: String?

    var id: String { stepId }

    enum CodingKeys: String, CodingKey {
        case stepId = "step_id"
        case techniqueId = "technique_id"
        case stepNumber = "step_number"
        case title
        case instruction
        case durationSeconds = "duration_seconds"
        case waterVolumeMlBase = "water_volume_ml_base"
        case imageName = "image_name"
    }
}
