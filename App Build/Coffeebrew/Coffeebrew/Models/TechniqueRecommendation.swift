import Foundation
import FoundationModels

@Generable
struct TechniqueRecommendation: Identifiable {
    var id: String { techniqueId }

    @Guide(description: "Exact technique ID string from the provided list")
    var techniqueId: String

    @Guide(description: "Human-readable technique name")
    var techniqueName: String

    @Guide(description: "Equipment name for this technique")
    var equipmentName: String

    @Guide(description: "Rank 1 = best match, 5 = fifth best")
    var rank: Int

    @Guide(description: "Match quality 0-100")
    var matchScore: Int

    @Guide(description: "2-3 sentences explaining why this technique suits the specific bean — reference actual flavour notes, process, and roast level")
    var reasoning: String

    @Guide(description: "Short benefit phrase, 5 words max, e.g. 'Highlights floral brightness'")
    var keyBenefit: String

    @Guide(description: "Optional caveats, e.g. ['Requires burr grinder']")
    var warnings: [String]
}

@Generable
struct RecommendationResponse {
    @Guide(description: "One sentence of overall brewing advice for this bean")
    var summary: String

    @Guide(description: "Top 5 ranked technique recommendations, best first")
    var recommendations: [TechniqueRecommendation]
}
