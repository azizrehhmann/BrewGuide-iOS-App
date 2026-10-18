import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var level: String = ""
    @State private var flavors: Set<String> = []
    @State private var gear: Set<String> = []
    @State private var morningTime: String = "07:30"
    @State private var notifications: Bool = false

    private let totalSteps = 7

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            // Top chrome (steps 1-5)
            if step > 0 && step < totalSteps - 1 {
                topChrome
            }

            // Step content
            Group {
                switch step {
                case 0: splashStep
                case 1: manifestoStep
                case 2: levelStep
                case 3: flavorStep
                case 4: gearStep
                case 5: ritualStep
                case 6: readyStep
                default: EmptyView()
                }
            }
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: step)
        }
    }

    // MARK: - Top Chrome

    private var topChrome: some View {
        VStack {
            HStack(spacing: 14) {
                Button {
                    withAnimation { step = max(0, step - 1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Constants.Colors.primaryColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(Constants.Colors.primaryColor.opacity(0.06))
                        )
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Constants.Colors.primaryColor.opacity(0.06))
                            .frame(height: 2)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Constants.Colors.accentGold)
                            .frame(width: geo.size.width * Double(step) / Double(totalSteps - 1), height: 2)
                            .animation(.easeInOut(duration: 0.45), value: step)
                    }
                }
                .frame(height: 2)

                Button {
                    finishOnboarding()
                } label: {
                    Text("Skip")
                        .font(Constants.Typography.sans(12))
                        .foregroundStyle(Constants.Colors.primaryColor.opacity(0.35))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 58)

            Spacer()
        }
        .zIndex(20)
    }

    // MARK: - Step 0: Splash

    private var splashStep: some View {
        VStack {
            Spacer()

            // A scale, a server and a V60 (Design/figures/brew)
            Image("figure_brew_full")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 340)
                .padding(.horizontal, 28)
                .accessibilityHidden(true)

            Spacer()

            VStack(alignment: .leading, spacing: 0) {
                KEyebrow(text: "Welcome to")
                    .padding(.bottom, 6)

                (Text("Kōhi")
                    .font(Constants.Typography.display(64))
                 + Text(".")
                    .font(Constants.Typography.display(64))
                    .foregroundColor(Constants.Colors.accentGold))
                .foregroundStyle(Constants.Colors.primaryColor)
                .padding(.bottom, 10)

                Text("The quiet ritual of a well-made cup — guided, step by step.")
                    .font(Constants.Typography.displayItalic(18))
                    .foregroundStyle(Constants.Colors.primaryColor.opacity(0.6))
                    .lineSpacing(4)
                    .padding(.bottom, 24)

                KButton(title: "Begin", icon: "arrow.right", variant: .primary) {
                    withAnimation { step = 1 }
                }

                Button {
                    finishOnboarding()
                } label: {
                    Text("I already have an account")
                        .font(Constants.Typography.sans(13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 1: Manifesto

    private var manifestoStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 120)

            KEyebrow(text: "Our philosophy")
                .padding(.bottom, 10)

            (Text("A brewing app\nbuilt around\n")
                .font(Constants.Typography.display(42))
             + Text("the ritual.")
                .font(Constants.Typography.displayItalic(42))
                .foregroundColor(Constants.Colors.accentGold))
            .foregroundStyle(Constants.Colors.primaryColor)
            .lineSpacing(-2)
            .padding(.bottom, 36)

            let pillars: [(icon: String, title: String, body: String)] = [
                ("clock", "Slow is better", "Great coffee rewards patience. Kōhi guides you, step by step — never rushed."),
                ("scalemass", "Precise, not fussy", "Grams, degrees, seconds — the basics, no gatekeeping. Adjust ratios to your taste."),
                ("book.closed", "Learn by doing", "Each brew quietly teaches extraction, channeling, and the why behind the how."),
            ]

            VStack(spacing: 0) {
                ForEach(Array(pillars.enumerated()), id: \.offset) { _, pillar in
                    HStack(alignment: .top, spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Constants.Colors.accentGold.opacity(0.10))
                                .frame(width: 36, height: 36)
                            Image(systemName: pillar.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Constants.Colors.accentGold)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(pillar.title)
                                .font(Constants.Typography.display(19))
                                .foregroundStyle(Constants.Colors.primaryColor)
                            Text(pillar.body)
                                .font(Constants.Typography.sans(13))
                                .foregroundStyle(Constants.Colors.primaryColor.opacity(0.6))
                                .lineSpacing(2)
                        }
                    }
                    .padding(.vertical, 18)

                    Divider().opacity(0.3)
                }
            }

            Spacer()

            KButton(title: "Continue", icon: "arrow.right", variant: .primary) {
                withAnimation { step = 2 }
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Step 2: Level

    private var levelStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 120)

            KEyebrow(text: "Step 1 of 4")
                .padding(.bottom, 10)

            (Text("Where are you\n")
                .font(Constants.Typography.display(42))
             + Text("in the journey?")
                .font(Constants.Typography.displayItalic(42))
                .foregroundColor(Constants.Colors.accentGold))
            .foregroundStyle(Constants.Colors.primaryColor)
            .padding(.bottom, 8)

            Text("We'll tune the app to your level — you can change this anytime.")
                .font(Constants.Typography.sans(14))
                .foregroundStyle(Constants.Colors.primaryColor.opacity(0.6))
                .lineSpacing(2)
                .padding(.bottom, 24)

            let levels: [(id: String, title: String, sub: String, body: String)] = [
                ("beginner", "Curious", "Never brewed before", "We'll start with forgiving techniques and teach the fundamentals as you go."),
                ("enthusiast", "Enthusiast", "Brewing 1–3 years", "Dial in recipes, track what works, explore new methods and origins."),
                ("pro", "Obsessed", "I own a refractometer", "Full parameter control and every recipe, advanced ones included."),
            ]

            VStack(spacing: 10) {
                ForEach(levels, id: \.id) { l in
                    let isSelected = level == l.id
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) { level = l.id }
                        HapticsManager.shared.selection()
                    } label: {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.title)
                                    .font(Constants.Typography.display(22))
                                Text(l.sub)
                                    .font(Constants.Typography.sans(12))
                                    .opacity(0.5)
                                Text(l.body)
                                    .font(Constants.Typography.sans(12))
                                    .opacity(isSelected ? 0.7 : 0.6)
                                    .lineSpacing(2)
                                    .padding(.top, 6)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            ZStack {
                                Circle()
                                    .strokeBorder(isSelected ? Color.clear : Constants.Colors.primaryColor.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                                if isSelected {
                                    Circle()
                                        .fill(Constants.Colors.accentGold)
                                        .frame(width: 20, height: 20)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(18)
                        .foregroundStyle(isSelected ? Constants.Colors.background : Constants.Colors.primaryColor)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(isSelected ? Constants.Colors.primaryColor : Constants.Colors.cardBackground)
                                .shadow(color: isSelected ? .black.opacity(0.22) : Constants.Shadows.cardColor, radius: isSelected ? 14 : Constants.Shadows.cardRadius, y: isSelected ? 10 : Constants.Shadows.cardY)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            KButton(title: "Continue", icon: "arrow.right", variant: .primary, disabled: level.isEmpty) {
                withAnimation { step = 3 }
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Step 3: Flavor

    private var flavorStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 120)

            KEyebrow(text: "Step 2 of 4")
                .padding(.bottom, 10)

            (Text("What do\nyou ")
                .font(Constants.Typography.display(42))
             + Text("love to taste?")
                .font(Constants.Typography.displayItalic(42))
                .foregroundColor(Constants.Colors.accentGold))
            .foregroundStyle(Constants.Colors.primaryColor)
            .padding(.bottom, 8)

            Text("Pick any that sound right.")
                .font(Constants.Typography.sans(14))
                .foregroundStyle(Constants.Colors.primaryColor.opacity(0.6))
                .padding(.bottom, 24)

            let flavorOptions: [(id: String, label: String, hint: String)] = [
                ("floral", "Floral", "Jasmine, bergamot"),
                ("fruity", "Fruity", "Stone, citrus, berry"),
                ("chocolate", "Chocolate", "Cocoa, dark choc"),
                ("nutty", "Nutty", "Almond, hazelnut"),
                ("caramel", "Caramel", "Brown sugar, toffee"),
                ("earthy", "Earthy", "Tobacco, cedar"),
                ("bright", "Bright", "Acidic, juicy"),
                ("rich", "Rich", "Full body, creamy"),
            ]

            FlowLayout(spacing: 8) {
                ForEach(flavorOptions, id: \.id) { f in
                    let isOn = flavors.contains(f.id)
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            if isOn { flavors.remove(f.id) } else { flavors.insert(f.id) }
                        }
                        HapticsManager.shared.selection()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.label)
                                .font(Constants.Typography.display(20))
                            Text(f.hint)
                                .font(Constants.Typography.sans(12))
                                .opacity(isOn ? 0.8 : 0.5)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .foregroundStyle(isOn ? .white : Constants.Colors.primaryColor)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isOn ? Constants.Colors.accentGold : Constants.Colors.cardBackground)
                                .shadow(color: isOn ? Constants.Colors.accentGold.opacity(0.3) : Constants.Shadows.cardColor, radius: isOn ? 7 : Constants.Shadows.cardRadius, y: isOn ? 4 : Constants.Shadows.cardY)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            KButton(
                title: flavors.isEmpty ? "Pick at least one" : "Continue with \(flavors.count)",
                icon: "arrow.right",
                variant: .primary,
                disabled: flavors.isEmpty
            ) {
                withAnimation { step = 4 }
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Step 4: Gear

    private var gearStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 120)

            KEyebrow(text: "Step 3 of 4")
                .padding(.bottom, 10)

            (Text("What's ")
                .font(Constants.Typography.display(42))
             + Text("on your counter?")
                .font(Constants.Typography.displayItalic(42))
                .foregroundColor(Constants.Colors.accentGold))
            .foregroundStyle(Constants.Colors.primaryColor)
            .padding(.bottom, 8)

            Text("Today's suggestion sticks to the gear you own.")
                .font(Constants.Typography.sans(14))
                .foregroundStyle(Constants.Colors.primaryColor.opacity(0.6))
                .padding(.bottom, 20)

            let gearOptions: [(id: String, label: String, cat: String)] = [
                ("v60-pour-over", "V60", "Pour over"),
                ("chemex", "Chemex", "Pour over"),
                ("kalita-wave", "Kalita Wave", "Pour over"),
                ("aeropress", "AeroPress", "Pressure"),
                ("french-press", "French Press", "Immersion"),
                ("moka-pot", "Moka Pot", "Stovetop"),
                ("espresso", "Espresso", "Machine"),
                ("scale", "Scale", "Essential"),
                ("grinder", "Grinder", "Essential"),
                ("kettle", "Gooseneck", "Essential"),
            ]

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(gearOptions, id: \.id) { g in
                        let isOn = gear.contains(g.id)
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                if isOn { gear.remove(g.id) } else { gear.insert(g.id) }
                            }
                            HapticsManager.shared.selection()
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(isOn ? Color.clear : Constants.Colors.primaryColor.opacity(0.2), lineWidth: 1.5)
                                        .frame(width: 18, height: 18)
                                    if isOn {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Constants.Colors.accentGold)
                                            .frame(width: 18, height: 18)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(g.label)
                                        .font(Constants.Typography.display(16))
                                        .foregroundStyle(Constants.Colors.primaryColor)
                                    Text(g.cat)
                                        .font(Constants.Typography.sans(11))
                                        .foregroundStyle(Constants.Colors.primaryColor.opacity(0.35))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Constants.Colors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(isOn ? Constants.Colors.accentGold : .clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            KButton(
                title: gear.isEmpty ? "Skip for now" : "Continue with \(gear.count)",
                icon: "arrow.right",
                variant: .primary
            ) {
                withAnimation { step = 5 }
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Step 5: Ritual

    private var ritualStep: some View {
        let times = ["05:30", "06:00", "06:30", "07:00", "07:30", "08:00", "08:30", "09:00", "10:00"]

        return VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 120)

            KEyebrow(text: "Step 4 of 4")
                .padding(.bottom, 10)

            (Text("Your ")
                .font(Constants.Typography.display(42))
             + Text("morning cup.")
                .font(Constants.Typography.displayItalic(42))
                .foregroundColor(Constants.Colors.accentGold))
            .foregroundStyle(Constants.Colors.primaryColor)
            .padding(.bottom, 8)

            Text("When do you usually brew? We'll have a method ready for you.")
                .font(Constants.Typography.sans(14))
                .foregroundStyle(Constants.Colors.primaryColor.opacity(0.6))
                .padding(.bottom, 24)

            // Big time display
            VStack(spacing: 10) {
                Text("Daily reminder")
                    .font(Constants.Typography.sans(13))
                    .foregroundStyle(Constants.Colors.primaryColor.opacity(0.35))

                Text(morningTime)
                    .font(Constants.Typography.display(68))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
            .cardStyle()
            .padding(.bottom, 18)

            // Time scrubber
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(times, id: \.self) { t in
                        let isOn = t == morningTime
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { morningTime = t }
                        } label: {
                            Text(t)
                                .font(Constants.Typography.sans(15))
                                .foregroundStyle(isOn ? .white : Constants.Colors.primaryColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    isOn ? Constants.Colors.accentGold : Constants.Colors.cardBackground,
                                    in: Capsule()
                                )
                                .monospacedDigit()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 20)

            // Notification toggle
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Constants.Colors.accentGold.opacity(0.10))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bell")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Constants.Colors.accentGold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Gentle reminders")
                        .font(Constants.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(Constants.Colors.primaryColor)
                    Text("A quiet nudge, never a buzz")
                        .font(Constants.Typography.sans(11))
                        .foregroundStyle(Constants.Colors.primaryColor.opacity(0.35))
                }

                Spacer()

                Toggle("", isOn: $notifications)
                    .labelsHidden()
                    .tint(Constants.Colors.accentGold)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Constants.Colors.primaryColor.opacity(0.06))
            )

            Spacer()

            KButton(title: "Continue", icon: "arrow.right", variant: .primary) {
                withAnimation { step = 6 }
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Step 6: Ready

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 96)

            // Check badge
            ZStack {
                Circle()
                    .fill(Constants.Colors.accentGold)
                    .frame(width: 72, height: 72)
                    .shadow(color: Constants.Colors.accentGold.opacity(0.35), radius: 14, y: 10)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 28)

            KEyebrow(text: "All set")
                .padding(.bottom, 10)

            (Text("Your\n")
                .font(Constants.Typography.display(46))
             + Text("ritual")
                .font(Constants.Typography.displayItalic(46))
                .foregroundColor(Constants.Colors.accentGold)
             + Text(" awaits.")
                .font(Constants.Typography.display(46)))
            .foregroundStyle(Constants.Colors.primaryColor)
            .padding(.bottom, 24)

            // Summary card
            VStack(spacing: 0) {
                Text("Your profile")
                    .font(Constants.Typography.sans(12))
                    .foregroundStyle(Constants.Colors.primaryColor.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)

                summaryRow(label: "Level", value: levelLabel)
                summaryRow(label: "Flavors", value: flavors.isEmpty ? "Any" : Array(flavors).prefix(3).map { $0.capitalized }.joined(separator: ", "))
                summaryRow(label: "Gear", value: "\(gear.count) item\(gear.count == 1 ? "" : "s")")
                summaryRow(label: "Reminder", value: morningTime, isLast: true)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
            .cardStyle()

            Spacer()

            KButton(title: "Enter Kōhi", icon: "arrow.right", variant: .primary) {
                finishOnboarding()
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Helpers

    private var levelLabel: String {
        switch level {
        case "beginner": return "Curious"
        case "enthusiast": return "Enthusiast"
        case "pro": return "Obsessed"
        default: return "Ready"
        }
    }

    private func summaryRow(label: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(Constants.Typography.sans(12))
                    .foregroundStyle(Constants.Colors.primaryColor.opacity(0.35))
                Spacer()
                Text(value)
                    .font(Constants.Typography.display(15))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .lineLimit(1)
            }
            .padding(.vertical, 10)

            if !isLast {
                Divider().opacity(0.3)
            }
        }
    }

    private func finishOnboarding() {
        appEnvironment.userLevel = level
        appEnvironment.userFlavorsRaw = Array(flavors).joined(separator: ",")
        appEnvironment.userGearRaw = Array(gear).joined(separator: ",")
        appEnvironment.morningBrewTime = morningTime
        appEnvironment.dailySuggestionNotification = notifications
        DailySuggestionService.scheduleDailyNotification(enabled: notifications, time: morningTime)
        hasSeenOnboarding = true
    }
}
