# Task: Prominent Water Volume Display During Brew Steps

## Goal
Make the water volume callout the most visually dominant element on any step that
involves adding water — bigger than the timer, impossible to miss, animated on entry.
Steps with no water addition are unchanged.

All changes are View-layer only. Do not touch ViewModels, timer logic, or data models.

---

## 1. Core component — `WaterCalloutView`

Create `Views/BrewGuide/WaterCalloutView.swift`.
This replaces whatever inline label currently shows water volume.

```swift
import SwiftUI

struct WaterCalloutView: View {
    let targetMl: Double
    let unit: VolumeUnit           // match existing app unit enum
    let stepTitle: String
    let isBloomStep: Bool

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    enum VolumeUnit { case ml, flOz }

    var body: some View {
        VStack(spacing: 6) {
            // Label row
            HStack(spacing: 6) {
                Image(systemName: isBloomStep ? "drop.circle" : "drop.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brewGold)
                Text(isBloomStep ? "Bloom water" : "Add water")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brewGold)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }

            // Big number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedAmount)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(unitLabel)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.brewGold.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.brewGold.opacity(0.25), lineWidth: 1)
                )
        )
        .scaleEffect(appeared ? 1.0 : 0.88)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                appeared = true
            }
        }
        .onChange(of: targetMl) { _ in
            // Re-animate when water amount changes (serving size scaler)
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                appeared = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                    appeared = true
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Helpers

    private var formattedAmount: String {
        switch unit {
        case .ml:   return String(format: "%.0f", targetMl)
        case .flOz: return String(format: "%.1f", targetMl / 29.5735)
        }
    }

    private var unitLabel: String {
        unit == .ml ? "ml" : "fl oz"
    }

    private var accessibilityText: String {
        "\(isBloomStep ? "Bloom water" : "Add water"): \(formattedAmount) \(unitLabel)"
    }
}
```

---

## 2. Cumulative pour tracker — `CumulativePourBar`

Shows how much total water has been added so far vs the recipe total.
Place this directly below `WaterCalloutView` on water steps.

Create `Views/BrewGuide/CumulativePourBar.swift`:

```swift
import SwiftUI

struct CumulativePourBar: View {
    let previousMl: Double     // water added before this step
    let currentStepMl: Double  // water being added in this step
    let totalRecipeMl: Double

    @State private var fillFraction: Double = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private var prevFraction: Double {
        guard totalRecipeMl > 0 else { return 0 }
        return min(previousMl / totalRecipeMl, 1.0)
    }

    private var targetFraction: Double {
        guard totalRecipeMl > 0 else { return 0 }
        return min((previousMl + currentStepMl) / totalRecipeMl, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    // Previous pours — muted gold
                    Capsule()
                        .fill(Color.brewGold.opacity(0.35))
                        .frame(width: geo.size.width * prevFraction, height: 8)

                    // This step's pour — bright gold, animates in
                    Capsule()
                        .fill(Color.brewGold)
                        .frame(width: geo.size.width * fillFraction, height: 8)
                        .animation(
                            reduceMotion ? .none : .easeOut(duration: 0.55).delay(0.2),
                            value: fillFraction
                        )
                }
            }
            .frame(height: 8)

            // Labels
            HStack {
                Text(String(format: "%.0f ml so far", previousMl + currentStepMl))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f ml total", totalRecipeMl))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear {
            fillFraction = targetFraction
        }
        .onChange(of: currentStepMl) { _ in
            fillFraction = prevFraction
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                fillFraction = targetFraction
            }
        }
        .accessibilityLabel(
            String(format: "%.0f of %.0f ml added", previousMl + currentStepMl, totalRecipeMl)
        )
    }
}
```

---

## 3. Layout rule in `BrewGuideView`

In the existing brew step view, apply this conditional layout:

```swift
// Inside the step content VStack, replace the current water label with:

if let water = currentStep.waterAmountMl, water > 0 {
    // Water step layout — callout is the hero element
    VStack(spacing: 12) {
        WaterCalloutView(
            targetMl: water * Double(servingSize),
            unit: volumeUnit,           // from existing settings/viewmodel
            stepTitle: currentStep.title,
            isBloomStep: currentStep.title.lowercased().contains("bloom") ||
                         currentStep.title.lowercased().contains("pre-infus")
        )

        CumulativePourBar(
            previousMl: cumulativeWaterBeforeCurrentStep,
            currentStepMl: water * Double(servingSize),
            totalRecipeMl: totalRecipeWaterMl
        )
    }
    .padding(.horizontal, 20)
    .transition(.opacity.combined(with: .scale(scale: 0.96)))

} else {
    // Non-water step — show nothing (or existing step note if present)
    EmptyView()
}
```

**Where to get these values from the existing ViewModel:**
- `water * Double(servingSize)` — scale by serving size exactly as parameters screen does
- `cumulativeWaterBeforeCurrentStep` — sum of `waterAmountMl` for all steps before `currentStepIndex`
- `totalRecipeWaterMl` — sum of `waterAmountMl` across all steps × servingSize
- `volumeUnit` — existing unit preference (ml / fl oz) already in ViewModel or Settings

Add these two computed properties to `BrewSessionViewModel` if not already present:

```swift
var cumulativeWaterBeforeCurrentStep: Double {
    steps.prefix(currentStepIndex)
        .compactMap(\.waterAmountMlBase)
        .reduce(0, +) * Double(servingSize)
}

var totalRecipeWaterMl: Double {
    steps
        .compactMap(\.waterAmountMlBase)
        .reduce(0, +) * Double(servingSize)
}
```

---

## 4. Flash animation on step entry

When the user lands on a water step (via next/previous or auto-advance), the big
number should flash gold briefly to draw the eye — even before they look at it.

Add to `WaterCalloutView`:

```swift
@State private var flashOpacity: Double = 0

// Inside body, overlay on the background:
.overlay(
    RoundedRectangle(cornerRadius: 20)
        .fill(Color.brewGold.opacity(flashOpacity))
        .allowsHitTesting(false)
)
.onAppear {
    guard !reduceMotion else { return }
    withAnimation(.easeIn(duration: 0.08)) { flashOpacity = 0.18 }
    withAnimation(.easeOut(duration: 0.35).delay(0.08)) { flashOpacity = 0 }
}
```

---

## 5. Haptic on water step entry

In `BrewGuideView`, when `currentStepIndex` changes to a step that has water,
fire a distinct haptic so the user feels the transition even with the phone face-down:

```swift
.onChange(of: currentStepIndex) { _ in
    if let water = currentStep.waterAmountMl, water > 0 {
        // Soft double-tap: "pay attention, add water now"
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.impactOccurred(intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            g.impactOccurred(intensity: 1.0)
        }
    }
}
```

If `HapticEngine.swift` already exists in the project, add a `waterStep()` case there
instead of inlining the generator.

---

## 6. Unit toggle — tap the unit label to switch

Let the user tap the "ml" / "fl oz" label directly in the callout to toggle units
without going to Settings. This is a convenience shortcut only — it must write
to the same UserDefaults key that Settings uses, so the preference persists.

Modify `WaterCalloutView` to accept a binding:

```swift
// Change signature:
@Binding var unit: VolumeUnit

// Wrap the unit label in a button:
Button {
    withAnimation(.spring(response: 0.3)) {
        unit = (unit == .ml) ? .flOz : .ml
        UserDefaults.standard.set(unit == .flOz, forKey: "volumeUnitIsFlOz")
    }
} label: {
    Text(unitLabel)
        .font(.system(size: 22, weight: .medium, design: .rounded))
        .foregroundStyle(Color.brewGold.opacity(0.7))
        .padding(.bottom, 8)
        .contentShape(Rectangle())
}
.buttonStyle(.plain)
.accessibilityLabel("Switch to \(unit == .ml ? "fl oz" : "ml")")
```

In `BrewGuideView`, pass `$volumeUnit` as a binding so the toggle propagates
back to the ViewModel / AppSettings.

---

## Files to create / modify

| File | Action |
|------|--------|
| `Views/BrewGuide/WaterCalloutView.swift` | Create |
| `Views/BrewGuide/CumulativePourBar.swift` | Create |
| `Views/BrewGuide/BrewGuideView.swift` | Modify — integrate both components, add haptic |
| `ViewModels/BrewSessionViewModel.swift` | Modify — add two computed properties if missing |

---

## Checklist

- [ ] `WaterCalloutView` renders on every step where `waterAmountMl > 0`
- [ ] Number size is at least 72pt — visually dominant over timer ring
- [ ] Spring scale-in animation fires on step entry
- [ ] Gold flash overlay fires on appear, fades within 400ms
- [ ] `.contentTransition(.numericText())` on the amount — smooth when serving size changes
- [ ] `CumulativePourBar` shows previous pours in muted gold, current step in bright gold
- [ ] Bar animates from prev fraction to target fraction with 0.2s delay
- [ ] Water steps with no water (`waterAmountMl == nil` or `0`) show nothing — `EmptyView`
- [ ] Bloom / pre-infusion steps show "Bloom water" label and drop.circle icon
- [ ] All other water steps show "Add water" label and drop.fill icon
- [ ] Tapping the unit label toggles ml ↔ fl oz and persists to UserDefaults
- [ ] Unit toggle uses same UserDefaults key as Settings screen
- [ ] Double haptic fires when navigating to a water step
- [ ] All animations gated on `@Environment(\.accessibilityReduceMotion)`
- [ ] VoiceOver reads combined label: "Add water: 120 ml"
- [ ] Dark mode verified — gold tint and muted fills readable on dark background
