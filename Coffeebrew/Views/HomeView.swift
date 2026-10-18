import SwiftUI
import CoreData

struct HomeView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var showSettings = false
    @State private var showBeanFirst = false
    @State private var showProfile = false
    @State private var navigationPath = NavigationPath()
    @ObservedObject private var authService = AuthenticationService.shared
    @State private var dailySuggestionService: DailySuggestionService?
    @State private var favRecentsVM: FavouritesRecentsViewModel?

    private var categories: [String] {
        appEnvironment.databaseService.categories
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    dailyRitualHeroCard
                    beanFirstCard
                    browseMethodsSection
                    favouritesRecentsSection
                    techniqueSpotlightSection
                }
                .padding(.vertical, 8)
                .padding(.bottom, 20)
            }
            .adaptiveBackground()
            .navigationDestination(for: String.self) { category in
                EquipmentListView(category: category)
            }
            .navigationDestination(for: BrewMethod.self) { method in
                TechniqueListView(method: method)
            }
            .navigationDestination(for: Technique.self) { technique in
                BeansView(technique: technique)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .navigationDestination(isPresented: $showBeanFirst) {
                BeanFirstEntryView(
                    databaseService: appEnvironment.databaseService,
                    onBrewTechnique: { technique in
                        showBeanFirst = false
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            navigationPath.append(technique)
                        }
                    }
                )
            }
        }
        .onReceive(appEnvironment.$selectedMethod) { method in
            if method == nil && !navigationPath.isEmpty {
                navigationPath = NavigationPath()
            }
        }
        .onAppear {
            initDailySuggestionIfNeeded()
            initFavRecentsIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            dailySuggestionService?.forceRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            dailySuggestionService?.refreshIfNeeded()
        }
    }

    // MARK: - Header

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        let date = formatter.string(from: Date()).uppercased()
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        return "\(date) \u{00B7} \(time)"
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<5: return "Good evening,"
        case 5..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default: return "Good evening,"
        }
    }

    private var userName: String {
        if authService.isSignedIn, let name = authService.userProfile?.displayName, !name.isEmpty {
            return name.components(separatedBy: " ").first ?? name
        }
        return "there."
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            KEyebrow(text: dateString, color: .secondary, showDot: false)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(greetingText)
                    .font(Constants.Typography.display(28, weight: .regular))
                    .foregroundStyle(Constants.Colors.primaryColor)

                Text(" ")

                if authService.isSignedIn, authService.userProfile?.displayName != nil {
                    Text(userName)
                        .font(Constants.Typography.displayItalic(28))
                        .foregroundStyle(Constants.Colors.accentGold)
                } else {
                    Text(userName)
                        .font(Constants.Typography.displayItalic(28))
                        .foregroundStyle(Constants.Colors.accentGold)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Constants.Layout.horizontalPadding)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Daily Ritual Hero Card

    private var dailyRitualHeroCard: some View {
        Group {
            if let service = dailySuggestionService, let suggestion = service.suggestion {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(alignment: .center) {
                        KEyebrow(text: "TODAY'S RITUAL", showDot: true)
                        Spacer()
                        if suggestion.streakDays > 0 {
                            Text("\(suggestion.streakDays)-day streak")
                                .font(Constants.Typography.mono(11))
                                .foregroundStyle(Constants.Colors.accentGold)
                        }
                    }
                    .padding(.bottom, 16)

                    // Technique name + image
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(suggestion.technique.name)
                                .font(Constants.Typography.display(34, weight: .regular))
                                .foregroundStyle(Constants.Colors.primaryColor)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(suggestion.flavourHook)
                                .font(Constants.Typography.displayItalic(16))
                                .foregroundStyle(Constants.Colors.accentGold)
                        }

                        Spacer(minLength: 12)

                        Image(suggestion.technique.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 96, height: 96)
                    }
                    .padding(.bottom, 20)

                    // Specs grid
                    specsGrid(for: suggestion.technique)
                        .padding(.bottom, 20)

                    // Begin brewing button
                    KButton(
                        title: "Begin brewing",
                        icon: "arrow.right",
                        variant: .gold,
                        action: {
                            service.recordSuggestionBrew()
                            navigationPath.append(suggestion.technique)
                        }
                    )
                }
                .padding(20)
                .elevatedCardStyle()
                .padding(.horizontal, Constants.Layout.horizontalPadding)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(Constants.Animation.standard, value: dailySuggestionService?.suggestion?.technique.techniqueId)
    }

    private func specsGrid(for technique: Technique) -> some View {
        let minutes = technique.totalTimeSeconds / 60
        let seconds = technique.totalTimeSeconds % 60
        let timeString = seconds > 0 ? "\(minutes):\(String(format: "%02d", seconds))" : "\(minutes):00"
        let ratioString = "1:\(String(format: "%.0f", technique.ratioWaterCoffee))"

        return HStack(spacing: 0) {
            specColumn(label: "TIME", value: timeString)
            specDivider
            specColumn(label: "TEMP", value: "\(technique.waterTempC)\u{00B0}C")
            specDivider
            specColumn(label: "RATIO", value: ratioString)
            specDivider
            specColumn(label: "GRIND", value: technique.grindSizeLabel)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Constants.Colors.primaryColor.opacity(0.04))
        )
    }

    private func specColumn(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(Constants.Typography.mono(9))
                .foregroundStyle(.secondary)
            Text(value)
                .font(Constants.Typography.mono(14))
                .foregroundStyle(Constants.Colors.primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var specDivider: some View {
        Rectangle()
            .fill(Constants.Colors.primaryColor.opacity(0.08))
            .frame(width: 0.5, height: 28)
    }

    private func initDailySuggestionIfNeeded() {
        guard dailySuggestionService == nil else {
            dailySuggestionService?.refreshIfNeeded()
            return
        }
        let service = DailySuggestionService(
            databaseService: appEnvironment.databaseService,
            context: managedObjectContext
        )
        service.refreshIfNeeded()
        dailySuggestionService = service
    }

    // MARK: - Bean First AI Card

    private var beanFirstCard: some View {
        Button {
            showBeanFirst = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Constants.Colors.accentGold.opacity(0.15), Constants.Colors.accentGold.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Constants.Colors.accentGold)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Bean First")
                        .font(Constants.Typography.sans(15, weight: .semibold))
                        .foregroundStyle(Constants.Colors.primaryColor)

                    Text("Scan a bag or pick a bean for AI recommendations")
                        .font(Constants.Typography.sans(12, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Constants.Layout.horizontalPadding)
        .accessibilityLabel("Bean First. Scan a coffee bag or pick a bean for AI-powered technique recommendations.")
    }

    // MARK: - Browse Methods

    private var browseMethodsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            KSectionHeader(title: "Browse Methods")
                .padding(.horizontal, Constants.Layout.horizontalPadding)

            if categories.isEmpty {
                EmptyStateView(
                    icon: "cup.and.saucer",
                    title: "No Methods Found",
                    message: "Brewing method data could not be loaded."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            NavigationLink(value: category) {
                                browseMethodCard(
                                    category: category,
                                    count: appEnvironment.databaseService.methods(forCategory: category).count
                                )
                            }
                            .buttonStyle(.scale)
                        }
                    }
                    .padding(.horizontal, Constants.Layout.horizontalPadding)
                }
            }
        }
    }

    private func browseMethodCard(category: String, count: Int) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Constants.CategoryTints.tint(for: category).opacity(0.10))
                    .frame(width: 48, height: 48)

                Image(systemName: categoryIcon(for: category))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Constants.CategoryTints.tint(for: category))
            }

            VStack(spacing: 2) {
                Text(LocalizedStringKey(category))
                    .font(Constants.Typography.sans(13, weight: .semibold))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text("\(count)")
                    .font(Constants.Typography.mono(11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 100, height: 110)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category), \(count) method\(count == 1 ? "" : "s")")
        .accessibilityHint("Double tap to browse \(category.lowercased()) equipment")
        .accessibilityAddTraits(.isButton)
    }

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Pour Over": return "drop.fill"
        case "Immersion": return "cup.and.saucer.fill"
        case "Pressure": return "gauge.with.dots.needle.bottom.50percent"
        case "Cold Brew": return "snowflake"
        case "Stovetop & Traditional": return "flame.fill"
        case "Machine": return "gearshape.2.fill"
        default: return "cup.and.saucer.fill"
        }
    }

    // MARK: - Favourites & Recents

    private var favouritesRecentsSection: some View {
        Group {
            if let vm = favRecentsVM, vm.hasContent {
                FavouritesRecentsSection(
                    viewModel: vm,
                    onSelectTechnique: { technique in
                        navigationPath.append(technique)
                    },
                    onQuickRebrew: { item in
                        navigationPath.append(item.technique)
                        HapticsManager.shared.impact(style: .medium)
                    }
                )
            }
        }
    }

    private func initFavRecentsIfNeeded() {
        if favRecentsVM == nil {
            favRecentsVM = FavouritesRecentsViewModel(
                context: managedObjectContext,
                databaseService: appEnvironment.databaseService
            )
        } else {
            favRecentsVM?.refresh()
        }
    }

    // MARK: - Technique Spotlight

    private var spotlightTechnique: Technique? {
        let withDeepDive = appEnvironment.databaseService.techniques.filter { $0.deepDive != nil }
        guard !withDeepDive.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return withDeepDive[day % withDeepDive.count]
    }

    private var techniqueSpotlightSection: some View {
        Group {
            if let technique = spotlightTechnique, let deepDive = technique.deepDive {
                TechniqueSpotlightCard(
                    technique: technique,
                    deepDive: deepDive,
                    onTap: { navigationPath.append(technique) }
                )
                .padding(.horizontal, Constants.Layout.horizontalPadding)
            }
        }
    }
}
