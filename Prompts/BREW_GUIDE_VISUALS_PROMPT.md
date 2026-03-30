# Task: Improve Step-by-Step Brew Guide Visuals & Animations

## Goal
Enhance the existing brew guide screen with richer visuals, smoother animations,
and clearer per-step feedback — without changing any data model, timer logic, or
navigation structure. All changes are purely in the View layer.

---

## 1. Step transition animation

Replace the current hard cut between steps with a directional slide + fade.

```swift
// In BrewGuideView, wrap step content in:
.transition(.asymmetric(
    insertion: .move(edge: .trailing).combined(with: .opacity),
    removal:   .move(edge: .leading).combined(with: .opacity)
))
.animation(.spring(response: 0.38, dampingFraction: 0.82), value: currentStepIndex)
.id(currentStepIndex)  // forces SwiftUI to treat each step as a distinct view
```

When going backwards (previous step button), reverse the direction:
```swift
// Track direction in BrewGuideView
@State private var stepDirection: Int = 1  // +1 forward, -1 backward

.transition(.asymmetric(
    insertion: stepDirection > 0
        ? .move(edge: .trailing).combined(with: .opacity)
        : .move(edge: .leading).combined(with: .opacity),
    removal: stepDirection > 0
        ? .move(edge: .leading).combined(with: .opacity)
        : .move(edge: .trailing).combined(with: .opacity)
))
```

---

## 2. Progress bar — segmented with animation

Replace the current single bar with a segmented bar where each segment fills
as the user completes each step.

Create `Views/BrewGuide/SegmentedProgressBar.swift`:

```swift
import SwiftUI

struct SegmentedProgressBar: View {
    let totalSteps: Int
    let currentStep: Int       // 1-based
    let accentColor: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...totalSteps, id: \.self) { step in
                Capsule()
                    .fill(segmentColor(for: step))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        // Animated fill for the current in-progress segment
                        if step == currentStep {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(accentColor)
                                    .frame(width: geo.size.width * 0.5)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                            .repeatForever(autoreverses: true),
                                        value: currentStep
                                    )
                            }
                        }
                    }
                    .animation(.spring(response: 0.4), value: currentStep)
            }
        }
        .frame(height: 4)
        .accessibilityLabel("Step \(currentStep) of \(totalSteps)")
    }

    private func segmentColor(for step: Int) -> Color {
        if step < currentStep  { return accentColor }
        if step == currentStep { return accentColor.opacity(0.35) }
        return Color(.systemGray5)
    }
}
```

---

## 3. Timer ring — graduated colour + pulse on completion

Replace the plain circular stroke with a timer ring that:
- Transitions green → amber → red as time runs low
- Pulses with a soft scale + glow when it reaches zero
- Shows a checkmark with a spring bounce when the step has no timer

Create `Views/BrewGuide/BrewTimerRing.swift`:

```swift
import SwiftUI

struct BrewTimerRing: View {
    let progress: Double           // 1.0 = full, 0.0 = empty
    let secondsRemaining: Int
    let totalSeconds: Int
    let isRunning: Bool
    let hasTimer: Bool
    let isPaused: Bool

    @State private var pulseScale: CGFloat = 1.0
    @State private var checkmarkScale: CGFloat = 0.0

    private var ringColor: Color {
        guard hasTimer else { return .clear }
        let ratio = totalSeconds > 0 ? Double(secondsRemaining) / Double(totalSeconds) : 0
        if ratio > 0.5 { return .brewGold }
        if ratio > 0.2 { return Color.orange }
        return Color.red.opacity(0.85)
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 8)

            if hasTimer {
                // Filled arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Centre content
                VStack(spacing: 2) {
                    Text(formattedTime)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isPaused ? .secondary : ringColor)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.linear(duration: 1), value: secondsRemaining)

                    Text(isPaused ? "paused" : "remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .scaleEffect(pulseScale)

            } else {
                // No-timer step — bouncing checkmark
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.brewGold)
                    .scaleEffect(checkmarkScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                            checkmarkScale = 1.0
                        }
                    }
                    .onChange(of: hasTimer) { _ in
                        checkmarkScale = 0
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                            checkmarkScale = 1.0
                        }
                    }
            }
        }
        .frame(width: 200, height: 200)
        .onChange(of: secondsRemaining) { remaining in
            guard hasTimer else { return }
            // Pulse when time is low
            if remaining <= 5 && remaining > 0 {
                withAnimation(.easeInOut(duration: 0.2).repeatCount(2, autoreverses: true)) {
                    pulseScale = 1.06
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    pulseScale = 1.0
                }
            }
            // Completion burst
            if remaining == 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    pulseScale = 1.12
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.spring(response: 0.25)) { pulseScale = 1.0 }
                }
            }
        }
    }

    private var formattedTime: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "0:%02d", s)
    }
}
```

---

## 4. Step type icon — animated on entry

Each step gets a contextual SF Symbol that animates in with a bounce when the step loads.
Add this above the instruction text.

Create `Views/BrewGuide/StepTypeIcon.swift`:

```swift
import SwiftUI

struct StepTypeIcon: View {
    let stepTitle: String
    let hasTimer: Bool
    let waterAmountMl: Double?

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.brewGold)
                .symbolEffect(.bounce, value: appeared)

            if let water = waterAmountMl, water > 0 {
                Text(String(format: "%.0f ml", water))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.brewGold)
                    .contentTransition(.numericText())
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.brewGold.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .onAppear { appeared = true }
    }

    private var iconName: String {
        let t = stepTitle.lowercased()
        if t.contains("bloom") || t.contains("pre-infus") { return "drop.circle" }
        if t.contains("pour") || t.contains("add water")  { return "drop.fill" }
        if t.contains("steep") || t.contains("infus") || t.contains("wait") { return "timer" }
        if t.contains("stir") || t.contains("swirl")      { return "arrow.clockwise.circle" }
        if t.contains("press") || t.contains("plunge")    { return "arrow.down.circle.fill" }
        if t.contains("remove") || t.contains("serve")    { return "cup.and.saucer.fill" }
        if t.contains("grind")                             { return "gearshape.fill" }
        if t.contains("rinse") || t.contains("filter")    { return "drop.triangle.fill" }
        if t.contains("flip") || t.contains("invert")     { return "arrow.up.and.down.circle" }
        if t.contains("open") || t.contains("close")      { return "switch.2" }
        return hasTimer ? "timer" : "checkmark.circle"
    }
}
```

---

## 5. Water pour visualiser

For steps that add water, show a simple animated fill bar below the instruction.
This gives a visual target for the pour weight.

Create `Views/BrewGuide/WaterFillBar.swift`:

```swift
import SwiftUI

struct WaterFillBar: View {
    let targetMl: Double
    let totalWaterMl: Double     // total water in the recipe (for scaling)
    let cumulativeMlSoFar: Double // water added in previous steps

    @State private var fillProgress: Double = 0

    private var previousFraction: Double {
        guard totalWaterMl > 0 else { return 0 }
        return min(cumulativeMlSoFar / totalWaterMl, 1.0)
    }

    private var currentFraction: Double {
        guard totalWaterMl > 0 else { return 0 }
        return min((cumulativeMlSoFar + targetMl) / totalWaterMl, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Pour target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0fg total after this step", cumulativeMlSoFar + targetMl))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.brewGold)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray6))
                        .frame(height: 14)

                    // Previous water (darker gold)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.brewGold.opacity(0.4))
                        .frame(width: geo.size.width * previousFraction, height: 14)

                    // New water being added (bright gold)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.brewGold)
                        .frame(width: geo.size.width * fillProgress, height: 14)
                        .animation(.easeOut(duration: 0.7).delay(0.15), value: fillProgress)
                }
            }
            .frame(height: 14)
        }
        .padding(.horizontal, 20)
        .onAppear {
            fillProgress = currentFraction
        }
        .onChange(of: targetMl) { _ in
            fillProgress = previousFraction
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                fillProgress = currentFraction
            }
        }
    }
}
```

---

## 6. Step completion burst

When the timer hits zero or the user taps "Next step," show a brief particle-style
burst before advancing. Use a pure SwiftUI confetti-free approach — expanding circles.

Create `Views/BrewGuide/StepCompletionBurst.swift`:

```swift
import SwiftUI

struct StepCompletionBurst: View {
    @Binding var trigger: Bool
    let color: Color

    @State private var rings: [BurstRing] = []

    struct BurstRing: Identifiable {
        let id = UUID()
        var scale: CGFloat = 0.3
        var opacity: Double = 0.6
    }

    var body: some View {
        ZStack {
            ForEach(rings) { ring in
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 200, height: 200)
                    .scaleEffect(ring.scale)
                    .opacity(ring.opacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { fired in
            guard fired else { return }
            for delay in [0.0, 0.08, 0.16] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let ring = BurstRing()
                    rings.append(ring)
                    withAnimation(.easeOut(duration: 0.55)) {
                        if let idx = rings.firstIndex(where: { $0.id == ring.id }) {
                            rings[idx].scale = 1.4
                            rings[idx].opacity = 0
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        rings.removeAll { $0.id == ring.id }
                    }
                }
            }
            DispatchQueue.main.async { trigger = false }
        }
    }
}
```

In `BrewGuideView`, add:
```swift
@State private var completionBurstTrigger = false

// In body, overlay the timer ring:
BrewTimerRing(...)
    .overlay {
        StepCompletionBurst(trigger: $completionBurstTrigger, color: .brewGold)
    }

// Fire when timer hits 0 or user taps next:
func onStepComplete() {
    completionBurstTrigger = true
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    // ... existing advance logic
}
```

---

## 7. Next step preview strip

Show the next step title as a faint peek at the bottom of the screen,
so the user knows what's coming.

Add to `BrewGuideView` body (above the navigation buttons):

```swift
// Next step preview
if let nextStep = steps[safe: currentStepIndex + 1] {
    HStack(spacing: 8) {
        Image(systemName: "arrow.right")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        Text("Next: \(nextStep.title)")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .transition(.opacity.combined(with: .move(edge: .bottom)))
    .animation(.easeInOut(duration: 0.3), value: currentStepIndex)
}
```

Add safe subscript to `Array` if not present in the project:
```swift
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

---

## 8. Haptic pattern — distinct per event

Replace any single `UIImpactFeedbackGenerator` calls with a semantic haptic map:

```swift
// Utils/HapticEngine.swift
import UIKit

enum HapticEngine {
    static func stepAdvance()    { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func stepBack()       { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func timerComplete()  { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func timerWarning()   {  // called at 5 seconds remaining
        let g = UIImpactFeedbackGenerator(style: .rigid)
        g.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { g.impactOccurred() }
    }
    static func brewComplete()   { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
```

Wire into existing timer logic:
- At `secondsRemaining == 5` → `HapticEngine.timerWarning()`
- At `secondsRemaining == 0` → `HapticEngine.timerComplete()`
- On `advanceStep()` → `HapticEngine.stepAdvance()`
- On `previousStep()` → `HapticEngine.stepBack()`
- On `completeBrew()` → `HapticEngine.brewComplete()`

---

## 9. Brew complete screen animation

On the final screen, animate in the completion state with a staggered entrance.

```swift
// BrewCompleteView.swift — replace static appearance with:
@State private var showIcon    = false
@State private var showTitle   = false
@State private var showSummary = false
@State private var showActions = false

var body: some View {
    VStack(spacing: 24) {
        Image(systemName: "cup.and.saucer.fill")
            .font(.system(size: 64))
            .foregroundStyle(Color.brewGold)
            .scaleEffect(showIcon ? 1.0 : 0.4)
            .opacity(showIcon ? 1 : 0)

        Text("Brew complete")
            .font(.title.weight(.semibold))
            .opacity(showTitle ? 1 : 0)
            .offset(y: showTitle ? 0 : 12)

        // summary card, action buttons...
    }
    .onAppear {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.1))  { showIcon    = true }
        withAnimation(.easeOut(duration: 0.35).delay(0.4))  { showTitle   = true }
        withAnimation(.easeOut(duration: 0.35).delay(0.6))  { showSummary = true }
        withAnimation(.easeOut(duration: 0.35).delay(0.85)) { showActions = true }
    }
}
```

---

## 10. Respect reduced motion

Wrap all non-essential animations in a reduced motion check:

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Replace spring animations:
.animation(reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.82), value: currentStepIndex)

// Skip burst entirely:
func onStepComplete() {
    if !reduceMotion { completionBurstTrigger = true }
    // ...
}
```

---

## Files to create / modify

| File | Action |
|------|--------|
| `Views/BrewGuide/SegmentedProgressBar.swift` | Create |
| `Views/BrewGuide/BrewTimerRing.swift` | Create (replaces existing timer view) |
| `Views/BrewGuide/StepTypeIcon.swift` | Create |
| `Views/BrewGuide/WaterFillBar.swift` | Create |
| `Views/BrewGuide/StepCompletionBurst.swift` | Create |
| `Utils/HapticEngine.swift` | Create (or extend existing haptic util) |
| `Views/BrewGuide/BrewGuideView.swift` | Modify — integrate all above |
| `Views/BrewGuide/BrewCompleteView.swift` | Modify — staggered entrance |

---

## Do not change

- Any ViewModel, timer logic, data models, or navigation structure
- The auto-advance toggle behaviour
- Existing unit tests
- The step data (title, instruction, duration, water volume) — read-only in views

---

## Checklist

- [ ] Step transitions slide left/right based on direction (forward vs back)
- [ ] `SegmentedProgressBar` replaces existing progress indicator
- [ ] `BrewTimerRing` uses green → amber → red colour transition
- [ ] Timer number uses `.contentTransition(.numericText(countsDown: true))`
- [ ] Pulse animation fires at ≤5 seconds remaining
- [ ] Completion burst fires on timer zero and on manual next-step tap
- [ ] `StepTypeIcon` shows correct SF Symbol per step type with bounce on entry
- [ ] Water fill bar visible on any step where `waterAmountMl > 0`
- [ ] Next step preview strip shows below instruction text
- [ ] `HapticEngine` used consistently across all step events
- [ ] Brew complete screen uses staggered entrance animation
- [ ] All animations respect `@Environment(\.accessibilityReduceMotion)`
- [ ] No-timer steps show tap icon, not a broken empty ring
- [ ] Dark mode verified across all new views
