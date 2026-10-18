import SwiftUI
import ActivityKit
import CoreData

struct BrewGuideView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var timer = BrewTimerService()
    private let liveActivityService = BrewLiveActivityService.shared
    let technique: Technique
    let coffeeGrams: Double
    let waterGrams: Double

    @State private var currentStepIndex = 0
    @State private var stepDirection: Int = 1
    @State private var showComplete = false
    @State private var autoAdvance = false
    @State private var didLoadDefaults = false
    @State private var showPostBrewRating = false
    @State private var savedSession: BrewSession?
    @State private var journalViewModel: BrewJournalViewModel?
    @State private var completionBurstTrigger = false
    @State private var cachedSteps: [BrewStep]?
    @State private var showSaveError = false

    private var steps: [BrewStep] {
        cachedSteps ?? appEnvironment.databaseService.steps(forTechniqueId: technique.techniqueId)
    }

    private var currentStep: BrewStep? {
        guard currentStepIndex >= 0, currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    private var isLastStep: Bool {
        currentStepIndex >= steps.count - 1
    }

    private var isTimedStep: Bool {
        currentStep?.durationSeconds ?? 0 > 0
    }

    /// Scale factor to convert base amounts (15g coffee) to user's selected amount
    private var scaleFactor: Double {
        let baseWater = 15.0 * technique.ratioWaterCoffee
        guard baseWater > 0 else { return 1.0 }
        return waterGrams / baseWater
    }

    /// Scaled water for the current step
    private func scaledWater(for step: BrewStep) -> Double {
        step.waterVolumeMlBase * scaleFactor
    }

    /// Cumulative scaled water added in steps before the current one
    private var cumulativeWaterMl: Double {
        guard currentStepIndex > 0 else { return 0 }
        return steps.prefix(currentStepIndex)
            .reduce(0.0) { $0 + scaledWater(for: $1) }
    }

    /// Total scaled water across all steps in the recipe
    private var totalRecipeWaterMl: Double {
        steps.reduce(0.0) { $0 + scaledWater(for: $1) }
    }

    /// Resolves template placeholders in instruction text with actual scaled amounts
    private func resolvedInstruction(for step: BrewStep) -> String {
        var text = step.instruction
        // Replace {water_total} before {water} to avoid partial match
        text = text.replacingOccurrences(
            of: "{water_total}",
            with: String(format: "%.0f", waterGrams)
        )
        text = text.replacingOccurrences(
            of: "{water}",
            with: String(format: "%.0f", scaledWater(for: step))
        )
        text = text.replacingOccurrences(
            of: "{coffee}",
            with: String(format: "%.0f", coffeeGrams)
        )
        return text
    }

    /// Returns the instruction as an AttributedString with numeric amounts (e.g. "250ml", "15g") highlighted in accent gold.
    private func highlightedInstruction(for step: BrewStep) -> AttributedString {
        let resolved = resolvedInstruction(for: step)
        var attributed = AttributedString(resolved)
        attributed.foregroundColor = UIColor.secondaryLabel

        let pattern = #"\b\d+(\.\d+)?\s*(ml|g|mL)\b"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = resolved as NSString
            let matches = regex.matches(in: resolved, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: resolved) else { continue }
                let matchStr = String(resolved[range])
                if let attrRange = attributed.range(of: matchStr) {
                    attributed[attrRange].foregroundColor = UIColor(Constants.Colors.accentGold)
                    attributed[attrRange].font = UIFont.systemFont(
                        ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                        weight: .semibold
                    )
                }
            }
        }
        return attributed
    }

    var body: some View {
        Group {
            if steps.isEmpty {
                EmptyStateView(
                    icon: "list.number",
                    title: "No Steps Available",
                    message: "This technique has no brewing steps defined."
                )
            } else {
                brewContent
            }
        }
        .adaptiveBackground()
        .navigationTitle(technique.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showComplete) {
            BrewCompleteView(technique: technique)
        }
        .alert("Couldn't save this brew", isPresented: $showSaveError) {
            Button("Try Again") { advanceStep() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The brew wasn't added to your journal. Check that your device has free storage and try again.")
        }
        .sheet(isPresented: $showPostBrewRating) {
            if let session = savedSession, let vm = journalViewModel {
                PostBrewRatingView(
                    session: session,
                    journalViewModel: vm,
                    isPresented: $showPostBrewRating
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            if !didLoadDefaults {
                didLoadDefaults = true
                autoAdvance = appEnvironment.autoAdvanceEnabled
                HapticsManager.shared.isEnabled = appEnvironment.hapticsEnabled
                // Cache steps once to avoid repeated dictionary lookups
                cachedSteps = appEnvironment.databaseService.steps(forTechniqueId: technique.techniqueId)
            }
            configureCurrentStep()
            startLiveActivityIfNeeded()
        }
        .onDisappear {
            if !showComplete {
                liveActivityService.endActivity(animated: false)
            }
        }
        .onChange(of: timer.stepCompleted) { _, completed in
            guard completed else { return }
            HapticsManager.shared.timerComplete()
            if !reduceMotion { completionBurstTrigger = true }
            if autoAdvance {
                advanceStep()
            }
        }
        .onChange(of: currentStepIndex) { _, _ in
            if let step = currentStep, step.waterVolumeMlBase > 0 {
                HapticsManager.shared.waterStep()
            }
        }
    }

    // MARK: - Helpers

    /// Whether the current step is a pour or bloom step (for visualization swap)
    private var isPourOrBloomStep: Bool {
        // Step titles in the data are often clock times, so key off water volume instead
        (currentStep?.waterVolumeMlBase ?? 0) > 0
    }

    /// Formatted elapsed time as m:ss
    private var elapsedTimeString: String {
        let mins = timer.totalElapsedSeconds / 60
        let secs = timer.totalElapsedSeconds % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }

    // MARK: - Brew Content

    private var brewContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Top chrome
                topChrome
                    .padding(.horizontal, Constants.Layout.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Centered content area
                Spacer()

                centeredContent
                    .id(currentStepIndex)
                    .transition(.asymmetric(
                        insertion: stepDirection > 0
                            ? .move(edge: .trailing).combined(with: .opacity)
                            : .move(edge: .leading).combined(with: .opacity),
                        removal: stepDirection > 0
                            ? .move(edge: .leading).combined(with: .opacity)
                            : .move(edge: .trailing).combined(with: .opacity)
                    ))
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.82),
                        value: currentStepIndex
                    )

                Spacer()

                // Up next pill
                upNextPill
                    .padding(.bottom, 16)

                // Bottom spacer for controls overlay
                Spacer()
                    .frame(height: 100)
            }

            // Bottom controls overlay
            bottomControls
        }
    }

    // MARK: - Top Chrome

    private var topChrome: some View {
        HStack(spacing: 12) {
            // Close button
            Button {
                timer.pause()
                liveActivityService.endActivity(animated: false)
                appEnvironment.reset()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .frame(width: 36, height: 36)
                    .background(Constants.Colors.primaryColor.opacity(0.06))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close brew session")

            // Segmented progress
            KSegmentedProgress(
                total: steps.count,
                current: currentStepIndex,
                progress: isTimedStep ? timer.stepProgress : 0
            )

            // Elapsed time
            Text(elapsedTimeString)
                .font(Constants.Typography.mono(12))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }

    // MARK: - Centered Content

    private var centeredContent: some View {
        VStack(spacing: 20) {
            // Phase eyebrow
            if let step = currentStep {
                KEyebrow(
                    text: "\(step.title.uppercased()) \u{00B7} STEP \(step.stepNumber) OF \(steps.count)"
                )
            }

            // Step title
            if let step = currentStep {
                Text(step.displayTitle)
                    .font(Constants.Typography.display(36))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .lineLimit(3)
            }

            // Visualization swap
            visualizationView
                .overlay {
                    StepCompletionBurst(
                        trigger: $completionBurstTrigger,
                        color: Constants.Colors.accentGold
                    )
                }
                .padding(.vertical, 4)

            // Body text (instruction)
            if let step = currentStep {
                Text(highlightedInstruction(for: step))
                    .font(Constants.Typography.sans(16))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Visualization View

    @ViewBuilder
    private var visualizationView: some View {
        if let step = currentStep {
            if isTimedStep && isPourOrBloomStep {
                KPourViz(
                    current: scaledWater(for: step) * timer.stepProgress,
                    target: scaledWater(for: step),
                    phase: step.displayTitle
                )
            } else if isTimedStep {
                KTimerRing(
                    progress: timer.stepProgress,
                    remaining: timer.stepRemainingSeconds,
                    total: timer.stepDurationSeconds,
                    phase: step.displayTitle
                )
            } else {
                KTimerRing(
                    progress: 0,
                    remaining: 0,
                    phase: step.displayTitle
                )
            }
        }
    }

    // MARK: - Up Next Pill

    @ViewBuilder
    private var upNextPill: some View {
        if let nextStep = steps[safe: currentStepIndex + 1] {
            HStack(spacing: 8) {
                Text("UP NEXT")
                    .font(Constants.Typography.mono(10))
                    .foregroundStyle(.tertiary)
                    .tracking(1)
                Text(nextStep.displayTitle)
                    .font(Constants.Typography.sans(13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Constants.Colors.primaryColor.opacity(0.04))
            .clipShape(Capsule())
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: currentStepIndex)
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 24) {
            // Previous
            Button {
                goToPreviousStep()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(currentStepIndex > 0 ? Constants.Colors.primaryColor : Constants.Colors.primaryColor.opacity(0.2))
                    .frame(width: 52, height: 52)
                    .background(Constants.Colors.cardBackground)
                    .clipShape(Circle())
                    .shadow(color: Constants.Shadows.cardColor, radius: Constants.Shadows.cardRadius, y: Constants.Shadows.cardY)
            }
            .disabled(currentStepIndex == 0)
            .accessibilityLabel("Previous step")

            // Play / Pause (center)
            Button {
                if isTimedStep {
                    let wasRunning = timer.isRunning
                    timer.toggle()
                    HapticsManager.shared.impact()
                    if wasRunning {
                        liveActivityService.pauseTimer(secondsRemaining: timer.stepRemainingSeconds)
                    } else {
                        let newEndTime = Date().addingTimeInterval(Double(timer.stepRemainingSeconds))
                        liveActivityService.resumeTimer(newEndTime: newEndTime)
                    }
                }
            } label: {
                Image(systemName: isTimedStep ? (timer.isRunning ? "pause.fill" : "play.fill") : "play.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Constants.Colors.accentGold)
                    .clipShape(Circle())
                    .shadow(color: Constants.Colors.accentGold.opacity(0.3), radius: 12, y: 4)
            }
            .disabled(!isTimedStep)
            .opacity(isTimedStep ? 1.0 : 0.4)
            .accessibilityLabel(timer.isRunning ? "Pause timer" : "Start timer")

            // Next / Complete
            Button {
                advanceStep()
            } label: {
                Image(systemName: isLastStep ? "checkmark" : "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .frame(width: 52, height: 52)
                    .background(Constants.Colors.cardBackground)
                    .clipShape(Circle())
                    .shadow(color: Constants.Shadows.cardColor, radius: Constants.Shadows.cardRadius, y: Constants.Shadows.cardY)
            }
            .accessibilityLabel(isLastStep ? "Complete brew" : "Next step")
        }
        .padding(.bottom, 32)
    }

    // MARK: - Step Navigation

    private func advanceStep() {
        guard !showComplete else { return }
        if isLastStep {
            timer.pause()
            // Stay on this step if the journal save fails so the user can retry
            guard saveBrewSession() else {
                showSaveError = true
                return
            }
            liveActivityService.endActivity(animated: true)
            if !reduceMotion { completionBurstTrigger = true }
            showComplete = true
            HapticsManager.shared.brewComplete()
        } else {
            stepDirection = 1
            if !reduceMotion { completionBurstTrigger = true }
            currentStepIndex += 1
            configureCurrentStep()
            liveActivityService.updateStep(makeCurrentState())
            HapticsManager.shared.stepAdvance()
        }
    }

    private func goToPreviousStep() {
        guard currentStepIndex > 0 else { return }
        stepDirection = -1
        currentStepIndex -= 1
        configureCurrentStep()
        HapticsManager.shared.stepBack()
    }

    private func configureCurrentStep() {
        guard let step = currentStep else { return }
        timer.configureStep(duration: step.durationSeconds)
        if timer.isRunning || (currentStepIndex > 0) {
            timer.start()
        }
    }

    // MARK: - Save Brew Session

    private func saveBrewSession() -> Bool {
        let vm = BrewJournalViewModel(context: managedObjectContext)
        journalViewModel = vm

        let method = appEnvironment.databaseService.method(byId: technique.methodId)
        let methodName = method?.category ?? "Unknown"
        let equipmentName = method?.name ?? "Unknown"

        let session = vm.saveSession(
            methodName: methodName,
            equipmentName: equipmentName,
            techniqueName: technique.name,
            techniqueId: technique.techniqueId,
            beanName: appEnvironment.selectedBean?.name,
            beanOrigin: appEnvironment.selectedBean?.origin,
            roastLevel: appEnvironment.selectedBean?.roastLevel,
            servingSize: appEnvironment.defaultServings,
            coffeeGrams: coffeeGrams,
            waterMl: waterGrams,
            grindSize: technique.grindSizeLabel,
            waterTempC: Double(technique.waterTempC),
            totalBrewTimeSeconds: timer.totalElapsedSeconds
        )
        guard !vm.saveFailed else { return false }
        savedSession = session

        // Deduct coffee from inventory bean if one was selected
        deductFromInventoryBean()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            showPostBrewRating = true
        }
        return true
    }

    private func deductFromInventoryBean() {
        guard let beanID = appEnvironment.selectedInventoryBeanID else { return }
        let request: NSFetchRequest<CoffeeBean> = CoffeeBean.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", beanID as CVarArg)
        request.fetchLimit = 1
        guard let bean = try? managedObjectContext.fetch(request).first else { return }
        BeanInventoryViewModel(context: managedObjectContext).deductWeight(from: bean, grams: coffeeGrams)
    }

    // MARK: - Live Activity

    private func startLiveActivityIfNeeded() {
        guard appEnvironment.liveActivityEnabled else { return }
        let method = appEnvironment.databaseService.method(byId: technique.methodId)
        let firstState = makeCurrentState()
        liveActivityService.startActivity(
            techniqueName: technique.name,
            equipmentName: method?.name ?? "Unknown",
            methodCategory: method?.category ?? "",
            totalSteps: steps.count,
            firstStep: firstState
        )
    }

    private func makeCurrentState() -> BrewActivityAttributes.ContentState {
        guard let step = currentStep else {
            return BrewLiveActivityService.makeState(
                currentStep: 1, totalSteps: steps.count,
                stepTitle: "", stepInstruction: "",
                stepDurationSeconds: 0, totalElapsedSeconds: 0,
                isTimerRunning: false, isTimerPaused: false,
                pausedSecondsRemaining: 0, waterAmountMl: nil
            )
        }
        return BrewLiveActivityService.makeState(
            currentStep: currentStepIndex + 1,
            totalSteps: steps.count,
            stepTitle: step.displayTitle,
            stepInstruction: resolvedInstruction(for: step),
            stepDurationSeconds: step.durationSeconds,
            totalElapsedSeconds: timer.totalElapsedSeconds,
            isTimerRunning: timer.isRunning,
            isTimerPaused: !timer.isRunning && timer.stepRemainingSeconds > 0 && timer.stepRemainingSeconds < step.durationSeconds,
            pausedSecondsRemaining: timer.stepRemainingSeconds,
            waterAmountMl: step.waterVolumeMlBase > 0 ? scaledWater(for: step) : nil
        )
    }
}
