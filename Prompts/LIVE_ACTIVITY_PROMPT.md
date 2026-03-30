# Task: Implement Live Activity with Dynamic Island for Brew Step Timer

## Overview

Add a **Live Activity** to BrewGuide that shows the current brew step timer on the
Lock Screen and in the Dynamic Island (iPhone 14 Pro+) while the user is away from the app.

When a brew starts, a Live Activity launches showing:
- Which step is active and how many remain
- A live countdown timer for the current step
- The technique name
- A tap-to-open deeplink back into the brew session

The Live Activity updates automatically on every step advance and ends when the brew completes.

**iOS target:** iOS 16.2+ (Live Activities require 16.1+; use iOS 17 APIs with availability checks)
**Architecture:** MVVM, matching existing project patterns
**No push notifications / remote updates needed** — all updates are local, driven by the app

---

## Project setup (do these first)

### 1. Add Widget Extension target

In Xcode:
- File → New → Target → Widget Extension
- Name it **`BrewGuideWidgetExtension`**
- **Uncheck** "Include Configuration Intent"
- **Check** "Include Live Activity"

This creates the extension target that hosts both widgets and Live Activities.

### 2. Info.plist entries

In the **main app** `Info.plist`, add:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

In the **widget extension** `Info.plist`, add:
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
</dict>
```

### 3. App Groups (required for data sharing)

- Main app target → Signing & Capabilities → + Capability → App Groups
- Add group: `group.com.yourcompany.brewguide` (match your actual bundle ID prefix)
- Widget extension target → same App Groups capability → same group identifier
- Replace `group.com.yourcompany.brewguide` everywhere in this prompt with the real group ID

### 4. Add ActivityKit to widget extension

The widget extension target must have `ActivityKit` and `WidgetKit` linked.
In the widget extension's target settings under Frameworks, confirm both are present.

---

## File structure

```
BrewGuideWidgetExtension/
├── BrewActivityAttributes.swift        (shared — add to BOTH targets)
├── BrewLiveActivityWidget.swift        (widget extension only)
├── BrewLockScreenView.swift            (widget extension only)
├── BrewDynamicIslandViews.swift        (widget extension only)
└── BrewGuideWidgetExtensionBundle.swift (widget extension entry point)

Main app/
├── BrewActivityAttributes.swift        (same file, added to main target too)
└── Services/BrewLiveActivityService.swift  (main app only)

ViewModels/
└── BrewSessionViewModel.swift          (existing — modify to call service)
```

**Critical:** `BrewActivityAttributes.swift` must be added to **both** the main app target
and the widget extension target. It is the contract between them.

---

## Step 1 — Shared attributes model

Create `BrewActivityAttributes.swift` and add it to **both targets**:

```swift
import ActivityKit
import Foundation

struct BrewActivityAttributes: ActivityAttributes {

    // MARK: - Static data (set at launch, never changes during the activity)

    let techniqueName: String
    let equipmentName: String
    let totalSteps: Int
    let methodCategory: String   // e.g. "Pour Over", used for icon selection

    // MARK: - Dynamic state (updated on every step change)

    struct ContentState: Codable, Hashable {
        let currentStep: Int              // 1-based
        let stepTitle: String             // e.g. "Second pour"
        let stepInstruction: String       // truncated to ~60 chars for display
        let stepDurationSeconds: Int      // 0 = no timer for this step
        let stepEndTime: Date?            // absolute end time for system timer (nil if no timer)
        let totalElapsedSeconds: Int      // cumulative brew time so far
        let isLastStep: Bool
        let isTimerPaused: Bool
        let pausedSecondsRemaining: Int   // only valid when isTimerPaused == true
        let waterAmountMl: Double?        // shown if this step adds water
    }
}

// MARK: - Convenience

extension BrewActivityAttributes.ContentState {
    var stepProgress: Double {
        // Not available here since totalSteps is on the outer struct
        // Compute in views using context.attributes.totalSteps
        0
    }

    var hasTimer: Bool { stepDurationSeconds > 0 }

    var truncatedInstruction: String {
        stepInstruction.count > 60
            ? String(stepInstruction.prefix(57)) + "…"
            : stepInstruction
    }
}
```

---

## Step 2 — BrewLiveActivityService

Create `Services/BrewLiveActivityService.swift` in the **main app target only**:

```swift
import ActivityKit
import Foundation

@MainActor
final class BrewLiveActivityService: ObservableObject {

    static let shared = BrewLiveActivityService()

    private var currentActivity: Activity<BrewActivityAttributes>?

    // MARK: - Start

    func startActivity(
        techniqueName: String,
        equipmentName: String,
        methodCategory: String,
        totalSteps: Int,
        firstStep: BrewActivityAttributes.ContentState
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled by user")
            return
        }

        // End any existing activity first
        Task { await endAllActivities() }

        let attributes = BrewActivityAttributes(
            techniqueName: techniqueName,
            equipmentName: equipmentName,
            totalSteps: totalSteps,
            methodCategory: methodCategory
        )

        let content = ActivityContent(
            state: firstStep,
            staleDate: firstStep.stepEndTime.map { $0.addingTimeInterval(30) }
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil   // local-only, no push
            )
            print("Live Activity started: \(currentActivity?.id ?? "nil")")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update on step change

    func updateStep(_ newState: BrewActivityAttributes.ContentState) {
        guard let activity = currentActivity else { return }

        let content = ActivityContent(
            state: newState,
            staleDate: newState.stepEndTime.map { $0.addingTimeInterval(30) }
        )

        Task {
            await activity.update(content)
        }
    }

    // MARK: - Pause / resume timer

    func pauseTimer(secondsRemaining: Int) {
        guard let activity = currentActivity else { return }
        var pausedState = activity.content.state
        // Create updated state with paused = true
        let updated = BrewActivityAttributes.ContentState(
            currentStep: pausedState.currentStep,
            stepTitle: pausedState.stepTitle,
            stepInstruction: pausedState.stepInstruction,
            stepDurationSeconds: pausedState.stepDurationSeconds,
            stepEndTime: nil,           // nil = timer not counting
            totalElapsedSeconds: pausedState.totalElapsedSeconds,
            isLastStep: pausedState.isLastStep,
            isTimerPaused: true,
            pausedSecondsRemaining: secondsRemaining,
            waterAmountMl: pausedState.waterAmountMl
        )
        Task {
            await activity.update(ActivityContent(state: updated, staleDate: nil))
        }
    }

    func resumeTimer(newEndTime: Date) {
        guard let activity = currentActivity else { return }
        let current = activity.content.state
        let updated = BrewActivityAttributes.ContentState(
            currentStep: current.currentStep,
            stepTitle: current.stepTitle,
            stepInstruction: current.stepInstruction,
            stepDurationSeconds: current.stepDurationSeconds,
            stepEndTime: newEndTime,
            totalElapsedSeconds: current.totalElapsedSeconds,
            isLastStep: current.isLastStep,
            isTimerPaused: false,
            pausedSecondsRemaining: 0,
            waterAmountMl: current.waterAmountMl
        )
        Task {
            await activity.update(ActivityContent(state: updated, staleDate: newEndTime.addingTimeInterval(30)))
        }
    }

    // MARK: - End

    func endActivity(animated: Bool = true) {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: animated ? .default : .immediate)
            currentActivity = nil
        }
    }

    private func endAllActivities() async {
        for activity in Activity<BrewActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }

    // MARK: - Helpers

    /// Build ContentState from the current step in BrewSessionViewModel
    static func makeState(
        currentStep: Int,
        totalSteps: Int,
        stepTitle: String,
        stepInstruction: String,
        stepDurationSeconds: Int,
        totalElapsedSeconds: Int,
        isTimerRunning: Bool,
        isTimerPaused: Bool,
        pausedSecondsRemaining: Int,
        waterAmountMl: Double?
    ) -> BrewActivityAttributes.ContentState {

        let endTime: Date? = (stepDurationSeconds > 0 && isTimerRunning && !isTimerPaused)
            ? Date().addingTimeInterval(Double(pausedSecondsRemaining > 0
                ? pausedSecondsRemaining
                : stepDurationSeconds))
            : nil

        return BrewActivityAttributes.ContentState(
            currentStep: currentStep,
            stepTitle: stepTitle,
            stepInstruction: stepInstruction,
            stepDurationSeconds: stepDurationSeconds,
            stepEndTime: endTime,
            totalElapsedSeconds: totalElapsedSeconds,
            isLastStep: currentStep == totalSteps,
            isTimerPaused: isTimerPaused,
            pausedSecondsRemaining: pausedSecondsRemaining,
            waterAmountMl: waterAmountMl
        )
    }
}
```

---

## Step 3 — Dynamic Island views

Create `BrewDynamicIslandViews.swift` in the **widget extension target**:

```swift
import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Compact leading (left of camera cutout)

struct BrewCompactLeadingView: View {
    let context: ActivityViewContext<BrewActivityAttributes>

    var body: some View {
        Image(systemName: methodIcon(context.attributes.methodCategory))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.brewGold)
            .frame(width: 28, height: 28)
    }
}

// MARK: - Compact trailing (right of camera cutout)

struct BrewCompactTrailingView: View {
    let context: ActivityViewContext<BrewActivityAttributes>

    var body: some View {
        let state = context.state

        Group {
            if state.hasTimer, let endTime = state.stepEndTime, !state.isTimerPaused {
                // System-driven countdown — updates without app being active
                Text(timerInterval: Date()...endTime, countsDown: true)
                    .monospacedDigit()
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, alignment: .trailing)
            } else if state.isTimerPaused {
                Text(formatSeconds(state.pausedSecondsRemaining))
                    .monospacedDigit()
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                // No timer step — show step progress fraction
                Text("\(state.currentStep)/\(context.attributes.totalSteps)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.trailing, 4)
    }
}

// MARK: - Minimal (tiny dot or small view on non-Pro iPhones)

struct BrewMinimalView: View {
    let context: ActivityViewContext<BrewActivityAttributes>

    var body: some View {
        Image(systemName: "timer")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.brewGold)
    }
}

// MARK: - Expanded (tapped Dynamic Island)

struct BrewExpandedView: View {
    let context: ActivityViewContext<BrewActivityAttributes>

    var body: some View {
        let state = context.state
        let attrs = context.attributes

        HStack(alignment: .center, spacing: 16) {
            // Left: method icon + step progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(
                        from: 0,
                        to: Double(state.currentStep) / Double(attrs.totalSteps)
                    )
                    .stroke(Color.brewGold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                    .animation(.easeInOut(duration: 0.4), value: state.currentStep)

                Image(systemName: methodIcon(attrs.methodCategory))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }

            // Centre: step info
            VStack(alignment: .leading, spacing: 3) {
                Text("Step \(state.currentStep) of \(attrs.totalSteps)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))

                Text(state.stepTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(state.truncatedInstruction)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: timer
            VStack(alignment: .trailing, spacing: 2) {
                if state.hasTimer {
                    if state.isTimerPaused {
                        Text(formatSeconds(state.pausedSecondsRemaining))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.5))
                        Text("paused")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    } else if let endTime = state.stepEndTime {
                        Text(timerInterval: Date()...endTime, countsDown: true)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.brewGold)
                        Text("remaining")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    Image(systemName: state.isLastStep ? "checkmark.circle.fill" : "hand.tap.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(state.isLastStep ? Color.brewGold : .white.opacity(0.7))
                    Text(state.isLastStep ? "Last step" : "Tap when done")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(minWidth: 68, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Helpers

func methodIcon(_ category: String) -> String {
    switch category.lowercased() {
    case let c where c.contains("pour"):    return "drop.fill"
    case let c where c.contains("french"):  return "cup.and.saucer.fill"
    case let c where c.contains("aero"):    return "arrow.down.circle.fill"
    case let c where c.contains("espresso"): return "bolt.fill"
    case let c where c.contains("cold"):    return "snowflake"
    case let c where c.contains("moka"):    return "flame.fill"
    default:                                return "cup.and.saucer"
    }
}

func formatSeconds(_ total: Int) -> String {
    let m = total / 60
    let s = total % 60
    return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "0:%02d", s)
}

extension Color {
    // Match the app's existing gold accent — replace with your actual Color asset
    static let brewGold = Color("BrewGold")
}
```

---

## Step 4 — Lock Screen view

Create `BrewLockScreenView.swift` in the **widget extension target**:

```swift
import SwiftUI
import ActivityKit
import WidgetKit

struct BrewLockScreenView: View {
    let context: ActivityViewContext<BrewActivityAttributes>

    var body: some View {
        let state = context.state
        let attrs = context.attributes

        HStack(spacing: 14) {
            // Left: circular progress
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(
                        from: 0,
                        to: Double(state.currentStep) / Double(attrs.totalSteps)
                    )
                    .stroke(Color.brewGold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)

                VStack(spacing: 0) {
                    Text("\(state.currentStep)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("of \(attrs.totalSteps)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            // Centre: step details
            VStack(alignment: .leading, spacing: 4) {
                Text(attrs.techniqueName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)

                Text(state.stepTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(state.truncatedInstruction)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)

                // Water callout
                if let water = state.waterAmountMl, water > 0 {
                    Label(String(format: "%.0f ml", water), systemImage: "drop.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.brewGold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: timer
            VStack(alignment: .trailing, spacing: 2) {
                if state.hasTimer {
                    if state.isTimerPaused {
                        Text(formatSeconds(state.pausedSecondsRemaining))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.5))
                        Text("paused")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                    } else if let endTime = state.stepEndTime {
                        Text(timerInterval: Date()...endTime, countsDown: true)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.brewGold)
                        Text("remaining")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    Image(systemName: state.isLastStep ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(state.isLastStep ? Color.brewGold : .white.opacity(0.7))
                }
            }
            .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(16)
        .activityBackgroundTint(Color.black.opacity(0.75))
        .activitySystemActionForegroundColor(.white)
    }
}
```

---

## Step 5 — Widget bundle entry point

Create or update `BrewGuideWidgetExtensionBundle.swift` in the **widget extension target**:

```swift
import WidgetKit
import SwiftUI
import ActivityKit

@main
struct BrewGuideWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        BrewLiveActivityWidget()
        // Add any existing home screen widgets here too
    }
}
```

Create `BrewLiveActivityWidget.swift` in the **widget extension target**:

```swift
import ActivityKit
import WidgetKit
import SwiftUI

struct BrewLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BrewActivityAttributes.self) { context in
            // Lock Screen / StandBy view
            BrewLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: methodIcon(context.attributes.methodCategory))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.brewGold)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.equipmentName)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.55))
                            Text(context.attributes.techniqueName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    let state = context.state
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Step \(state.currentStep) of \(context.attributes.totalSteps)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))

                        // Step progress pills
                        HStack(spacing: 3) {
                            ForEach(1...min(context.attributes.totalSteps, 7), id: \.self) { i in
                                Capsule()
                                    .fill(i <= state.currentStep ? Color.brewGold : Color.white.opacity(0.2))
                                    .frame(width: i == state.currentStep ? 14 : 6, height: 4)
                                    .animation(.spring(response: 0.3), value: state.currentStep)
                            }
                            if context.attributes.totalSteps > 7 {
                                Text("…")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    BrewExpandedView(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }

            } compactLeading: {
                BrewCompactLeadingView(context: context)
            } compactTrailing: {
                BrewCompactTrailingView(context: context)
            } minimal: {
                BrewMinimalView(context: context)
            }
            .widgetURL(URL(string: "brewguide://brew/resume"))
            .keylineTint(Color.brewGold)
        }
    }
}
```

---

## Step 6 — Wire into BrewSessionViewModel

In the **existing** `BrewSessionViewModel`, add Live Activity calls at the key lifecycle points.

### 6a. Add the service property

```swift
// At the top of BrewSessionViewModel
private let liveActivityService = BrewLiveActivityService.shared
```

### 6b. On brew start (when user taps "Begin Brew")

Call this after setting up the first step:

```swift
func startBrew() {
    // ... existing start logic ...

    // Start Live Activity
    let firstState = makeCurrentState()
    liveActivityService.startActivity(
        techniqueName: currentTechnique.name,
        equipmentName: currentEquipment.name,
        methodCategory: currentMethod.categoryName,
        totalSteps: steps.count,
        firstStep: firstState
    )
}
```

### 6c. On step advance (next step, auto-advance, or timer completion)

```swift
func advanceToNextStep() {
    // ... existing step advance logic ...

    // Update Live Activity
    let newState = makeCurrentState()
    liveActivityService.updateStep(newState)
}
```

### 6d. On timer pause / resume

```swift
func pauseTimer() {
    // ... existing pause logic ...
    liveActivityService.pauseTimer(secondsRemaining: currentSecondsRemaining)
}

func resumeTimer() {
    // ... existing resume logic ...
    let newEndTime = Date().addingTimeInterval(Double(currentSecondsRemaining))
    liveActivityService.resumeTimer(newEndTime: newEndTime)
}
```

### 6e. On brew complete

```swift
func completeBrew() {
    // ... existing completion logic ...
    liveActivityService.endActivity(animated: true)
}
```

### 6f. On brew cancelled / back button

```swift
func cancelBrew() {
    // ... existing cancel logic ...
    liveActivityService.endActivity(animated: false)
}
```

### 6g. Helper — makeCurrentState()

Add this private helper to `BrewSessionViewModel`:

```swift
private func makeCurrentState() -> BrewActivityAttributes.ContentState {
    let currentStepData = steps[currentStepIndex]
    return BrewLiveActivityService.makeState(
        currentStep: currentStepIndex + 1,
        totalSteps: steps.count,
        stepTitle: currentStepData.title,
        stepInstruction: currentStepData.instruction,
        stepDurationSeconds: currentStepData.durationSeconds,
        totalElapsedSeconds: totalElapsedSeconds,
        isTimerRunning: timerIsRunning,
        isTimerPaused: timerIsPaused,
        pausedSecondsRemaining: currentSecondsRemaining,
        waterAmountMl: currentStepData.waterVolumeMlBase.map {
            $0 * Double(servingSize)
        }
    )
}
```

---

## Step 7 — Deeplink handling (tap Live Activity → open app to brew screen)

The Live Activity sets `.widgetURL(URL(string: "brewguide://brew/resume"))`.

In your `@main` App struct or root view, handle the URL:

```swift
.onOpenURL { url in
    if url.scheme == "brewguide", url.host == "brew", url.path == "/resume" {
        // Navigate to the active brew screen
        // Implement based on your existing navigation structure
        // e.g. set a @Published var on a shared AppState object:
        appState.shouldShowActiveBrew = true
    }
}
```

In `BrewSessionViewModel` or `AppState`, expose whether a brew is currently active so the
navigation stack can respond to the deeplink correctly.

---

## Step 8 — Preview support for Xcode previews

Add this at the bottom of `BrewLiveActivityWidget.swift` for Live Activity previews in Xcode:

```swift
#if DEBUG
extension BrewActivityAttributes {
    static var preview: BrewActivityAttributes {
        BrewActivityAttributes(
            techniqueName: "James Hoffmann Method",
            equipmentName: "Hario V60",
            totalSteps: 6,
            methodCategory: "Pour Over"
        )
    }
}

extension BrewActivityAttributes.ContentState {
    static var previewStep2: BrewActivityAttributes.ContentState {
        .init(
            currentStep: 2,
            stepTitle: "Second pour",
            stepInstruction: "Pour 120g in a slow spiral from the centre outward.",
            stepDurationSeconds: 45,
            stepEndTime: Date().addingTimeInterval(38),
            totalElapsedSeconds: 52,
            isLastStep: false,
            isTimerPaused: false,
            pausedSecondsRemaining: 0,
            waterAmountMl: 120
        )
    }

    static var previewPaused: BrewActivityAttributes.ContentState {
        .init(
            currentStep: 3,
            stepTitle: "Drawdown",
            stepInstruction: "Wait for the coffee to draw down through the filter.",
            stepDurationSeconds: 60,
            stepEndTime: nil,
            totalElapsedSeconds: 110,
            isLastStep: false,
            isTimerPaused: true,
            pausedSecondsRemaining: 23,
            waterAmountMl: nil
        )
    }

    static var previewNoTimer: BrewActivityAttributes.ContentState {
        .init(
            currentStep: 6,
            stepTitle: "Serve",
            stepInstruction: "Remove the dripper and pour into your cup.",
            stepDurationSeconds: 0,
            stepEndTime: nil,
            totalElapsedSeconds: 210,
            isLastStep: true,
            isTimerPaused: false,
            pausedSecondsRemaining: 0,
            waterAmountMl: nil
        )
    }
}

#Preview("Lock Screen — Timer running", as: .content,
         using: BrewActivityAttributes.preview) {
    BrewLiveActivityWidget()
} contentStates: {
    BrewActivityAttributes.ContentState.previewStep2
    BrewActivityAttributes.ContentState.previewPaused
    BrewActivityAttributes.ContentState.previewNoTimer
}

#Preview("Dynamic Island — Compact", as: .dynamicIsland(.compact),
         using: BrewActivityAttributes.preview) {
    BrewLiveActivityWidget()
} contentStates: {
    BrewActivityAttributes.ContentState.previewStep2
}

#Preview("Dynamic Island — Expanded", as: .dynamicIsland(.expanded),
         using: BrewActivityAttributes.preview) {
    BrewLiveActivityWidget()
} contentStates: {
    BrewActivityAttributes.ContentState.previewStep2
    BrewActivityAttributes.ContentState.previewPaused
}

#Preview("Dynamic Island — Minimal", as: .dynamicIsland(.minimal),
         using: BrewActivityAttributes.preview) {
    BrewLiveActivityWidget()
} contentStates: {
    BrewActivityAttributes.ContentState.previewStep2
}
#endif
```

---

## Step 9 — Settings toggle (respect user preference)

The existing Settings screen has a haptics toggle. Add a Live Activity toggle alongside it.

In `SettingsView` (or wherever app settings are managed):

```swift
// In the settings list
Toggle("Show brew timer on Lock Screen", isOn: $showLiveActivity)
    .onChange(of: showLiveActivity) { newValue in
        UserDefaults.standard.set(newValue, forKey: "showLiveActivity")
    }
```

In `BrewSessionViewModel.startBrew()`:

```swift
let showLiveActivity = UserDefaults.standard.bool(forKey: "showLiveActivity")
// Default to true if key not yet set
if showLiveActivity || !UserDefaults.standard.contains("showLiveActivity") {
    liveActivityService.startActivity(...)
}
```

Add `contains` helper to `UserDefaults` if not already present:
```swift
extension UserDefaults {
    func contains(_ key: String) -> Bool {
        object(forKey: key) != nil
    }
}
```

---

## Step 10 — Unit tests

Create `Tests/BrewLiveActivityServiceTests.swift` in the **main app test target**:

```swift
import XCTest
import ActivityKit
@testable import BrewGuide

final class BrewLiveActivityServiceTests: XCTestCase {

    func test_makeState_withTimer_setsEndTime() {
        let state = BrewLiveActivityService.makeState(
            currentStep: 2,
            totalSteps: 5,
            stepTitle: "Second pour",
            stepInstruction: "Pour 120g slowly.",
            stepDurationSeconds: 45,
            totalElapsedSeconds: 55,
            isTimerRunning: true,
            isTimerPaused: false,
            pausedSecondsRemaining: 0,
            waterAmountMl: 120
        )
        XCTAssertNotNil(state.stepEndTime)
        XCTAssertTrue(state.hasTimer)
        XCTAssertFalse(state.isTimerPaused)
        XCTAssertFalse(state.isLastStep)
    }

    func test_makeState_noTimer_nilEndTime() {
        let state = BrewLiveActivityService.makeState(
            currentStep: 1,
            totalSteps: 5,
            stepTitle: "Add coffee",
            stepInstruction: "Grind and add 20g.",
            stepDurationSeconds: 0,
            totalElapsedSeconds: 0,
            isTimerRunning: false,
            isTimerPaused: false,
            pausedSecondsRemaining: 0,
            waterAmountMl: nil
        )
        XCTAssertNil(state.stepEndTime)
        XCTAssertFalse(state.hasTimer)
    }

    func test_makeState_paused_nilEndTime() {
        let state = BrewLiveActivityService.makeState(
            currentStep: 3,
            totalSteps: 5,
            stepTitle: "Steep",
            stepInstruction: "Wait for drawdown.",
            stepDurationSeconds: 60,
            totalElapsedSeconds: 100,
            isTimerRunning: true,
            isTimerPaused: true,
            pausedSecondsRemaining: 23,
            waterAmountMl: nil
        )
        XCTAssertNil(state.stepEndTime)
        XCTAssertTrue(state.isTimerPaused)
        XCTAssertEqual(state.pausedSecondsRemaining, 23)
    }

    func test_makeState_lastStep_flagSet() {
        let state = BrewLiveActivityService.makeState(
            currentStep: 6,
            totalSteps: 6,
            stepTitle: "Serve",
            stepInstruction: "Remove dripper and serve.",
            stepDurationSeconds: 0,
            totalElapsedSeconds: 240,
            isTimerRunning: false,
            isTimerPaused: false,
            pausedSecondsRemaining: 0,
            waterAmountMl: nil
        )
        XCTAssertTrue(state.isLastStep)
    }

    func test_truncatedInstruction_longText_truncates() {
        let state = BrewLiveActivityService.makeState(
            currentStep: 1, totalSteps: 3,
            stepTitle: "Test",
            stepInstruction: String(repeating: "A", count: 80),
            stepDurationSeconds: 30, totalElapsedSeconds: 0,
            isTimerRunning: false, isTimerPaused: false,
            pausedSecondsRemaining: 0, waterAmountMl: nil
        )
        XCTAssertEqual(state.truncatedInstruction.count, 60)
        XCTAssertTrue(state.truncatedInstruction.hasSuffix("…"))
    }

    func test_truncatedInstruction_shortText_unchanged() {
        let short = "Pour slowly."
        let state = BrewLiveActivityService.makeState(
            currentStep: 1, totalSteps: 3,
            stepTitle: "Test",
            stepInstruction: short,
            stepDurationSeconds: 30, totalElapsedSeconds: 0,
            isTimerRunning: false, isTimerPaused: false,
            pausedSecondsRemaining: 0, waterAmountMl: nil
        )
        XCTAssertEqual(state.truncatedInstruction, short)
    }
}
```

---

## Checklist

### Xcode project setup
- [ ] Widget Extension target created named `BrewGuideWidgetExtension`
- [ ] `NSSupportsLiveActivities = true` in main app Info.plist
- [ ] `NSSupportsLiveActivitiesFrequentUpdates = true` in main app Info.plist
- [ ] App Groups capability added to both main app and widget extension targets
- [ ] Group identifier matches exactly in both targets
- [ ] `BrewActivityAttributes.swift` added to **both** target memberships

### Files created
- [ ] `BrewActivityAttributes.swift` (both targets)
- [ ] `Services/BrewLiveActivityService.swift` (main app)
- [ ] `BrewLiveActivityWidget.swift` (widget extension)
- [ ] `BrewLockScreenView.swift` (widget extension)
- [ ] `BrewDynamicIslandViews.swift` (widget extension)
- [ ] `BrewGuideWidgetExtensionBundle.swift` (widget extension, includes `BrewLiveActivityWidget`)

### Integration
- [ ] `liveActivityService.startActivity()` called on brew start
- [ ] `liveActivityService.updateStep()` called on every step advance
- [ ] `liveActivityService.pauseTimer()` / `resumeTimer()` wired to existing pause/resume
- [ ] `liveActivityService.endActivity()` called on brew complete and brew cancel
- [ ] `makeCurrentState()` helper added to `BrewSessionViewModel`
- [ ] Deeplink `brewguide://brew/resume` handled in App struct to navigate to active brew
- [ ] Settings toggle for Live Activity added and respected in `startBrew()`

### Testing & verification
- [ ] All 5 unit tests passing
- [ ] Xcode previews render for Lock Screen, Compact, Expanded, Minimal
- [ ] Tested on iPhone 14 Pro simulator for Dynamic Island appearance
- [ ] Tested on iPhone 15 simulator (no Dynamic Island) for Lock Screen only
- [ ] Activity ends correctly when brew completes (not lingering)
- [ ] Activity ends correctly when user taps back/cancel mid-brew
- [ ] Tapping Live Activity opens app to the active brew screen

### Edge cases verified
- [ ] Steps with `duration_seconds = 0` show no countdown (arrow icon instead)
- [ ] Paused timer shows greyed-out static time, not a live countdown
- [ ] Techniques with more than 7 steps show truncated pill indicator with "…"
- [ ] Long step titles truncate cleanly at 1 line in all three Dynamic Island regions
- [ ] Live Activity does not start if user has disabled it in Settings
