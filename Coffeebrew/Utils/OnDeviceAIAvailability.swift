import FoundationModels

enum OnDeviceAIAvailability {
    case available
    case unavailable(reason: String)

    static func check() -> OnDeviceAIAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(reason: "On-device AI requires iPhone 15 Pro or iPhone 16 and later.")
            case .appleIntelligenceNotEnabled:
                return .unavailable(reason: "Enable Apple Intelligence in Settings → Apple Intelligence & Siri.")
            case .modelNotReady:
                return .unavailable(reason: "Apple Intelligence model is downloading. Try again shortly.")
            @unknown default:
                return .unavailable(reason: "On-device AI is not available on this device.")
            }
        @unknown default:
            return .unavailable(reason: "On-device AI is not available on this device.")
        }
    }

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var unavailableReason: String {
        if case .unavailable(let reason) = self { return reason }
        return "On-device AI unavailable."
    }
}
