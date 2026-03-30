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

    // MARK: - Brew Content

    private var brewContent: some View {
        VStack(spacing: 0) {
            SegmentedProgressBar(
                totalSteps: steps.count,
                currentStep: currentStepIndex + 1,
                accentColor: Constants.Colors.accentGold
            )
            .padding(.horizontal, Constants.Layout.horizontalPadding)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 20) {
                    // Method photo (collapsed header)
                    if let photoName = technique.methodPhoto {
                        Image(photoName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, .black.opacity(0.3)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .overlay(alignment: .bottomLeading) {
                                Text(technique.name)
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(12)
                            }
                    }

                    stepHeader
                    stepTypeIcon
                    instructionText
                    waterCalloutSection

                    if isTimedStep {
                        BrewTimerRing(
                            progress: timer.stepProgress,
                            secondsRemaining: timer.stepRemainingSeconds,
                            totalSeconds: timer.stepDurationSeconds,
                            isRunning: timer.isRunning,
                            hasTimer: true,
                            isPaused: !timer.isRunning && timer.stepRemainingSeconds > 0
                        )
                        .overlay {
                            StepCompletionBurst(
                                trigger: $completionBurstTrigger,
                                color: Constants.Colors.accentGold
                            )
                        }
                        .padding(.vertical, 8)

                        totalTimeLabel
                        autoAdvanceToggle
                    } else {
                        BrewTimerRing(
                            progress: 0,
                            secondsRemaining: 0,
                            totalSeconds: 0,
                            isRunning: false,
                            hasTimer: false,
                            isPaused: false
                        )
                        .overlay {
                            StepCompletionBurst(
                                trigger: $completionBurstTrigger,
                                color: Constants.Colors.accentGold
                            )
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
                .padding(.vertical, 12)
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
            }

            nextStepPreview
            bottomControls
                .padding(.horizontal, Constants.Layout.horizontalPadding)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Step Header

    private var stepHeader: some View {
        VStack(spacing: 4) {
            if let step = currentStep {
                Text("Step \(step.stepNumber) of \(steps.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Constants.Colors.accentGold)
                    .textCase(.uppercase)
                    .tracking(1)

                Text(step.title)
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Step Type Icon

    @ViewBuilder
    private var stepTypeIcon: some View {
        if let step = currentStep {
            StepTypeIcon(
                stepTitle: step.title,
                hasTimer: step.durationSeconds > 0
            )
        }
    }

    // MARK: - Instruction Text

    private var instructionText: some View {
        Group {
            if let step = currentStep {
                Text(resolvedInstruction(for: step))
                    .font(Constants.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Water Callout Section

    @ViewBuilder
    private var waterCalloutSection: some View {
        if let step = currentStep, step.waterVolumeMlBase > 0 {
            let stepWater = scaledWater(for: step)
            let title = step.title.lowercased()
            let isBloom = title.contains("bloom") || title.contains("pre-infus")
                || resolvedInstruction(for: step).lowercased().contains("bloom")

            VStack(spacing: 12) {
                WaterCalloutView(
                    targetMl: stepWater,
                    useFluidOunces: $appEnvironment.useFluidOunces,
                    stepTitle: step.title,
                    isBloomStep: isBloom
                )

                CumulativePourBar(
                    previousMl: cumulativeWaterMl,
                    currentStepMl: stepWater,
                    totalRecipeMl: totalRecipeWaterMl
                )
            }
            .padding(.horizontal, 4)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    // MARK: - Total Time

    private var totalTimeLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption)
            Text("Total: \(timer.totalElapsedSeconds.shortFormattedTime)")
                .font(.caption.weight(.medium).monospacedDigit())
        }
        .foregroundStyle(.secondary)
        .accessibilityLabel("Total brew time: \(timer.totalElapsedSeconds.formattedTime)")
    }

    // MARK: - Auto-Advance Toggle

    private var autoAdvanceToggle: some View {
        Toggle(isOn: $autoAdvance) {
            Label("Auto-advance steps", systemImage: "forward.fill")
                .font(.caption)
        }
        .toggleStyle(.switch)
        .tint(Constants.Colors.accentGold)
        .accessibilityLabel("Auto-advance to next step when timer completes")
    }

    // MARK: - Next Step Preview

    @ViewBuilder
    private var nextStepPreview: some View {
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
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: currentStepIndex)
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 16) {
            // Previous
            Button {
                goToPreviousStep()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(currentStepIndex > 0 ? Constants.Colors.primaryColor : .gray.opacity(0.3))
            }
            .disabled(currentStepIndex == 0)
            .accessibilityLabel("Previous step")

            if isTimedStep {
                // Play / Pause — only for timed steps
                Button {
                    let wasRunning = timer.isRunning
                    timer.toggle()
                    HapticsManager.shared.impact()
                    if wasRunning {
                        liveActivityService.pauseTimer(secondsRemaining: timer.stepRemainingSeconds)
                    } else {
                        let newEndTime = Date().addingTimeInterval(Double(timer.stepRemainingSeconds))
                        liveActivityService.resumeTimer(newEndTime: newEndTime)
                    }
                } label: {
                    Image(systemName: timer.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Constants.Colors.accentGold)
                }
                .accessibilityLabel(timer.isRunning ? "Pause timer" : "Start timer")
            }

            // Next / Complete
            Button {
                advanceStep()
            } label: {
                Image(systemName: isLastStep ? "checkmark.circle.fill" : "chevron.right.circle.fill")
                    .font(.system(size: isTimedStep ? 44 : 64))
                    .foregroundStyle(isTimedStep ? nextButtonColor : Constants.Colors.accentGold)
            }
            .accessibilityLabel(isLastStep ? "Complete brew" : "Next step")
        }
        .frame(minHeight: 64)
    }

    private var nextButtonColor: Color {
        if let step = currentStep, step.durationSeconds > 0 {
            let canAdvance = timer.stepRemainingSeconds <= 5 || timer.stepCompleted || !timer.isRunning
            return canAdvance ? Constants.Colors.primaryColor : Constants.Colors.primaryColor.opacity(0.3)
        }
        return Constants.Colors.primaryColor
    }

    // MARK: - Step Navigation

    private func advanceStep() {
        if isLastStep {
            timer.pause()
            liveActivityService.endActivity(animated: true)
            if !reduceMotion { completionBurstTrigger = true }
            saveBrewSession()
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

    private func saveBrewSession() {
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
        savedSession = session

        // Deduct coffee from inventory bean if one was selected
        deductFromInventoryBean()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            showPostBrewRating = true
        }
    }

    private func deductFromInventoryBean() {
        guard let beanID = appEnvironment.selectedInventoryBeanID else { return }
        let request: NSFetchRequest<CoffeeBean> = CoffeeBean.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", beanID as CVarArg)
        request.fetchLimit = 1
        guard let bean = try? managedObjectContext.fetch(request).first else { return }
        // Deduct directly instead of creating a throwaway ViewModel
        bean.remainingWeightGrams = max(0, bean.remainingWeightGrams - coffeeGrams)
        if bean.remainingWeightGrams <= 0 {
            bean.isActive = false
        }
        if managedObjectContext.hasChanges,
           let coordinator = managedObjectContext.persistentStoreCoordinator,
           !coordinator.persistentStores.isEmpty {
            try? managedObjectContext.save()
        }
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
            stepTitle: step.title,
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
