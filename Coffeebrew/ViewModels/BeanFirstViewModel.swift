import Combine
import CoreData
import SwiftUI
import UIKit

final class BeanFirstViewModel: ObservableObject {

    // MARK: - State Machine

    enum FlowState: Equatable {
        case entry
        case scanning
        case scanProcessing
        case confirmBean(BeanProfile)
        case loading
        case results(BeanProfile)
        case error(String)

        static func == (lhs: FlowState, rhs: FlowState) -> Bool {
            switch (lhs, rhs) {
            case (.entry, .entry), (.scanning, .scanning), (.scanProcessing, .scanProcessing),
                 (.loading, .loading):
                return true
            case (.confirmBean(let a), .confirmBean(let b)):
                return a.id == b.id
            case (.results(let a), .results(let b)):
                return a.id == b.id
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    @Published var state: FlowState = .entry
    @Published var aiAvailability: OnDeviceAIAvailability = .available
    @Published var recommendations: RecommendationResponse?
    @Published var capturedImage: UIImage?
    @Published var scannedText: String?

    private let aiService = AIRecommendationService()
    private let scannerService = BeanScannerService()
    let databaseService: DatabaseService

    // MARK: - Init

    init(databaseService: DatabaseService) {
        self.databaseService = databaseService
        self.aiAvailability = OnDeviceAIAvailability.check()
    }

    // MARK: - Actions

    /// User selected a bean from inventory
    func selectInventoryBean(_ coffeeBean: CoffeeBean) {
        let profile = BeanProfile(from: coffeeBean)
        state = .confirmBean(profile)
    }

    /// User captured an image from camera
    func handleCapturedImage(_ image: UIImage) {
        capturedImage = image
        state = .scanProcessing

        Task {
            do {
                let rawText = try await scannerService.recognizeText(from: image)
                scannedText = rawText

                let parsed = try await aiService.parseScannedText(rawText)
                let profile = BeanProfile(from: parsed)

                await MainActor.run {
                    state = .confirmBean(profile)
                }
            } catch {
                await MainActor.run {
                    state = .error(error.localizedDescription)
                }
            }
        }
    }

    /// User confirmed the bean profile — get recommendations
    func confirmBean(_ bean: BeanProfile) {
        state = .loading
        recommendations = nil

        Task {
            do {
                let techniques = databaseService.techniques
                let response = try await aiService.recommendTechniques(
                    for: bean,
                    techniques: techniques,
                    databaseService: databaseService
                )

                await MainActor.run {
                    recommendations = response
                    state = .results(bean)
                }
            } catch {
                await MainActor.run {
                    state = .error(error.localizedDescription)
                }
            }
        }
    }

    /// Reset to entry
    func reset() {
        state = .entry
        recommendations = nil
        capturedImage = nil
        scannedText = nil
    }

    /// Go back one step
    func goBack() {
        switch state {
        case .scanning, .scanProcessing:
            state = .entry
        case .confirmBean:
            if capturedImage != nil {
                state = .entry
            } else {
                state = .entry
            }
        case .results:
            state = .entry
        case .error:
            state = .entry
        default:
            break
        }
    }

    /// Resolve a recommendation's techniqueId to a Technique object
    func technique(for recommendation: TechniqueRecommendation) -> Technique? {
        databaseService.technique(byId: recommendation.techniqueId)
    }
}
