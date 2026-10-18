import FoundationModels
import Foundation

final class AIRecommendationService {

    // MARK: - Parse scanned bag text into structured bean data

    func parseScannedText(_ rawText: String) async throws -> ScannedBeanData {
        guard OnDeviceAIAvailability.check().isAvailable else {
            throw AIError.notAvailable
        }

        let session = LanguageModelSession()

        let prompt = """
        The following text was scanned from a coffee bag label using OCR. \
        Extract structured information about the coffee bean. \
        If a field is not mentioned or unclear, omit it.

        Scanned text:
        \(rawText)
        """

        let response = try await session.respond(
            to: prompt,
            generating: ScannedBeanData.self
        )
        return response.content
    }

    // MARK: - Recommend techniques for a bean

    func recommendTechniques(
        for bean: BeanProfile,
        techniques: [Technique],
        databaseService: DatabaseService
    ) async throws -> RecommendationResponse {
        guard OnDeviceAIAvailability.check().isAvailable else {
            throw AIError.notAvailable
        }

        let session = LanguageModelSession(
            instructions: """
            You are a world-class coffee consultant. \
            Recommend brewing techniques that best match the given bean's \
            characteristics. Always reference the bean's specific process, \
            roast level, and flavour notes in your reasoning.
            """
        )

        let techniqueList = techniques.map { t in
            let method = databaseService.method(byId: t.methodId)
            let equipName = method?.name ?? "Unknown"
            return "id:\(t.techniqueId) | \(t.name) (\(equipName)) | \(t.grindSizeLabel) grind | \(t.waterTempC)°C | ratio 1:\(t.ratioWaterCoffee)"
        }.joined(separator: "\n")

        let prompt = """
        Bean profile:
        \(bean.aiDescription)

        Available techniques (id | name | equipment | grind | temp | ratio):
        \(techniqueList)

        Rank the top 5 techniques for this specific bean. \
        Consider how the process and roast interact with each extraction method, \
        how the flavour notes are best amplified, and temperature sensitivity. \
        Return exactly 5 recommendations, ranked 1 (best) to 5.
        """

        let response = try await session.respond(
            to: prompt,
            generating: RecommendationResponse.self
        )
        return response.content
    }

    // MARK: - Errors

    enum AIError: LocalizedError {
        case notAvailable
        case scanFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return OnDeviceAIAvailability.check().unavailableReason
            case .scanFailed(let detail):
                return "Could not read the bag label. \(detail)"
            }
        }
    }
}
