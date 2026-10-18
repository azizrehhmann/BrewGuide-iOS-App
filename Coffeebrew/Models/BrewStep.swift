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

    /// The data's `title` is often a clock time ("0:10", "1:55-3:30"); fall back to the
    /// instruction's first clause so headings read as words.
    var displayTitle: String {
        guard title.allSatisfy({ $0.isNumber || ":-– ".contains($0) }) else { return title }
        let head = instruction.prefix { !":;.".contains($0) }.trimmingCharacters(in: .whitespaces)
        return head.isEmpty ? title : head
    }

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
