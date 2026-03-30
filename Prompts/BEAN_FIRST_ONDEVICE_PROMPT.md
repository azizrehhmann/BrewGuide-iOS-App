# Task: Bean-First Flow — On-Device AI with Apple Intelligence

## Overview

Replace the previous Claude API implementation with fully **on-device AI** using
Apple's Foundation Models framework (iOS 18.1+). No API key, no network calls,
no cost per inference. All processing stays on device.

The feature has two entry paths:
1. **Inventory pick** — select a saved bean, get ranked technique recommendations
2. **Camera scan** — scan a bag label; Vision reads the text; on-device LLM parses
   it into structured bean data; same recommendation engine runs

**Minimum deployment target: iOS 18.1**
**Required device: iPhone 15 Pro / iPhone 16+ (A17 Pro or M-series chip)**
The app must gracefully degrade on unsupported devices.

---

## Key framework changes vs the previous Claude API version

| Concern | Previous (Claude API) | Now (on-device) |
|---|---|---|
| LLM calls | `URLSession` → `api.anthropic.com` | `LanguageModelSession` (Foundation Models) |
| API key | Required, stored in xcconfig | None needed |
| Network | Required | Zero — fully offline |
| Availability | All iOS 17 devices | iOS 18.1+, A17 Pro or M-series only |
| Latency | ~2–4s (network round trip) | ~1–3s (on-device inference) |
| Privacy | Data leaves device | Data never leaves device |
| Structured output | Parse JSON string from response | Native `@Generable` macro — type-safe |

---

## Step 1 — Availability gate

Before any Foundation Models call, always check availability. Add this helper:

```swift
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
        }
    }
}
```

Show a clear, actionable message in the UI when unavailable — never a silent failure.

---

## Step 2 — Structured output models with @Generable

Foundation Models' `@Generable` macro lets the model return type-safe Swift structs
directly — no JSON parsing, no string wrangling.

Add to `Models/BeanProfile.swift` (extend the existing struct):

```swift
import FoundationModels

// Parsed output from a scanned bag label
@Generable
struct ScannedBeanData {
    @Guide(description: "Full bean name including roaster if visible, e.g. 'Square Mile Red Brick'")
    var name: String

    @Guide(description: "Roaster name only, if clearly stated on the label")
    var roaster: String?

    @Guide(description: "Country of origin, e.g. 'Ethiopia'")
    var origin: String?

    @Guide(description: "Specific region or farm, e.g. 'Yirgacheffe'")
    var region: String?

    @Guide(description: "Processing method: Washed, Natural, Honey, or Other")
    var process: String?

    @Guide(description: "Roast level: Light, Medium-Light, Medium, Medium-Dark, or Dark")
    var roastLevel: String?

    @Guide(description: "Flavour descriptors listed on the bag, e.g. ['Blueberry', 'Jasmine']")
    var flavourNotes: [String]

    @Guide(description: "Growing altitude if stated, e.g. '1800-2200m'")
    var altitude: String?

    @Guide(description: "Coffee variety if stated, e.g. 'Heirloom' or 'Bourbon'")
    var variety: String?
}
```

Add to `Models/TechniqueRecommendation.swift`:

```swift
import FoundationModels

@Generable
struct TechniqueRecommendation: Identifiable {
    var id: UUID = UUID()

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
```

---

## Step 3 — AIRecommendationService (replace entirely)

Delete the previous `URLSession`-based implementation.
Create `Services/AIRecommendationService.swift`:

```swift
import FoundationModels
import Vision
import UIKit

final class AIRecommendationService {

    // MARK: - Parse scanned bag text into structured bean data

    func parseScannedText(_ rawText: String) async throws -> ScannedBeanData {
        guard case .available = OnDeviceAIAvailability.check() else {
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
        techniques: [Technique]
    ) async throws -> RecommendationResponse {
        guard case .available = OnDeviceAIAvailability.check() else {
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
            "id:\(t.id) | \(t.name) (\(t.equipmentName)) | \(t.grindSizeLabel) grind | \(Int(t.waterTempC))°C | ratio 1:\(t.ratioCoffeeToWater)"
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

    // MARK: - Streaming variant (for progressive UI reveal)

    func streamRecommendations(
        for bean: BeanProfile,
        techniques: [Technique],
        onPartial: @escaping (RecommendationResponse.PartiallyGenerated) -> Void
    ) async throws -> RecommendationResponse {
        guard case .available = OnDeviceAIAvailability.check() else {
            throw AIError.notAvailable
        }

        let session = LanguageModelSession(
            instructions: "You are a world-class coffee consultant specialising in brew method matching."
        )

        let techniqueList = techniques.map { t in
            "id:\(t.id) | \(t.name) (\(t.equipmentName)) | \(t.grindSizeLabel) grind | \(Int(t.waterTempC))°C"
        }.joined(separator: "\n")

        let prompt = """
        Bean: \(bean.aiDescription)

        Techniques:
        \(techniqueList)

        Rank top 5 techniques for this bean with reasoning.
        """

        let stream = session.streamResponse(
            to: prompt,
            generating: RecommendationResponse.self
        )

        var final: RecommendationResponse?
        for try await partial in stream {
            onPartial(partial)
        }

        // Await the fully resolved response
        let result = try await session.respond(
            to: prompt,
            generating: RecommendationResponse.self
        )
        return result.content
    }

    enum AIError: LocalizedError {
        case notAvailable

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return OnDeviceAIAvailability.check().unavailableReason
            }
        }
    }
}

// MARK: - Convenience

private extension OnDeviceAIAvailability {
    var unavailableReason: String {
        if case .unavailable(let reason) = self { return reason }
        return "On-device AI unavailable."
    }
}
```

---

## Step 4 — BeanFirstViewModel changes

Only two changes needed — remove `apiKey` concerns, add availability check on init:

```swift
@MainActor
final class BeanFirstViewModel: ObservableObject {

    @Published var aiAvailability: OnDeviceAIAvailability = .available

    // Add to init:
    init() {
        aiAvailability = OnDeviceAIAvailability.check()
    }

    // handleCapturedImage and confirmBean stay identical to the previous prompt —
    // they call the same AIRecommendationService methods, which now use
    // Foundation Models internally instead of URLSession.
    // No other changes needed in this file.
}
```

---

## Step 5 — Availability UI in BeanFirstEntryView

Show a clear degraded state when the device doesn't support on-device AI:

```swift
// In BeanFirstEntryView body, wrap AI entry points:
if case .available = viewModel.aiAvailability {
    // Show scan + recommend buttons normally
    BeanScanCard()
    BeanInventoryCard()
} else if case .unavailable(let reason) = viewModel.aiAvailability {
    ContentUnavailableView(
        "Apple Intelligence required",
        systemImage: "brain",
        description: Text(reason)
    )
    // Still show manual inventory browsing — no AI needed for that
    BeanInventoryCard()
}
```

---

## Step 6 — Streaming UI in BeanRecommendationsView (optional enhancement)

Foundation Models supports streaming partial structs. Use this to reveal recommendations
progressively rather than showing a spinner until all 5 are ready:

```swift
// In BeanFirstViewModel:
func confirmBeanWithStreaming(_ bean: BeanProfile) {
    state = .loading
    Task {
        do {
            let techniques = databaseService.allTechniques
            let response = try await aiService.streamRecommendations(
                for: bean,
                techniques: techniques,
                onPartial: { [weak self] partial in
                    // partial.recommendations may have 1, 2, 3... items as they arrive
                    if let recs = partial.recommendations, !recs.isEmpty {
                        self?.partialRecommendations = recs.compactMap { $0 }
                    }
                }
            )
            state = .results(response)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
```

In `BeanRecommendationsView`, show `partialRecommendations` while loading instead of
a full-screen spinner — cards appear one by one as the model generates them.

---

## Xcode project requirements

- **Deployment target:** iOS 18.1 minimum
- **Frameworks to link:** `FoundationModels.framework` (add in target → Frameworks, Libraries)
- **Entitlement:** Add `com.apple.developer.apple-intelligence` to the `.entitlements` file
  (required for `LanguageModelSession` access)
- **Xcode version:** 16.2 or later required for Foundation Models SDK

No Info.plist changes needed — camera usage description from the previous implementation
still applies.

---

## What does NOT change from the previous prompt

- `BeanProfile` model (except adding `@Generable ScannedBeanData` as a separate type)
- `BeanInventoryService` — unchanged
- `BeanScannerService` — Vision OCR pipeline unchanged
- All five views — `BeanFirstEntryView`, `BeanScannerView`, `BeanConfirmView`,
  `BeanRecommendationsView`, `BeanInventoryView` — unchanged except the availability UI
  addition in Step 5
- `BeanFirstViewModel` flow state machine — unchanged except `aiAvailability` property

---

## Checklist

- [ ] Deployment target set to iOS 18.1 in project settings
- [ ] `FoundationModels.framework` linked in target
- [ ] `com.apple.developer.apple-intelligence` entitlement added
- [ ] `OnDeviceAIAvailability.check()` helper created
- [ ] `ScannedBeanData` struct marked `@Generable` with `@Guide` annotations
- [ ] `TechniqueRecommendation` and `RecommendationResponse` marked `@Generable`
- [ ] `AIRecommendationService` rewritten to use `LanguageModelSession`
- [ ] `parseScannedText` uses `session.respond(to:generating:)` with `ScannedBeanData.self`
- [ ] `recommendTechniques` uses `session.respond(to:generating:)` with `RecommendationResponse.self`
- [ ] Streaming variant implemented for progressive card reveal (optional)
- [ ] `BeanFirstEntryView` shows `ContentUnavailableView` on unsupported devices
- [ ] Manual inventory browsing still works on unsupported devices
- [ ] No API keys, no URLSession calls, no network dependency in AI path
- [ ] Tested on iPhone 15 Pro simulator (iOS 18.1+) — AI path works
- [ ] Tested on iPhone 14 simulator — graceful degradation shown
