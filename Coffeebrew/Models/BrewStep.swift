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
        let head = instruction.prefix { !":;.(\u{2014}\u{2013}".contains($0) }
        // Instructions carry {coffee}/{water} placeholders that are only resolved for the body text
        let clean = String(head)
            .replacingOccurrences(of: #"\{[a-z_]+\}g?\s?"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return clean.isEmpty ? title : clean
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
