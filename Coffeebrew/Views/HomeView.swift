import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var showSettings = false
    @State private var showBeanFirst = false
    @Binding var navigationPath: NavigationPath
    @ObservedObject private var authService = AuthenticationService.shared
    @State private var dailySuggestionService: DailySuggestionService?
    @State private var favRecentsVM: FavouritesRecentsViewModel?

    private var categories: [String] {
        appEnvironment.databaseService.categories
    }

    var body: some View {
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
        Date().formatted(.dateTime.weekday(.wide).day().month(.wide))
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
        HStack(alignment: .top, spacing: 8) {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateString)
                .font(Constants.Typography.sans(14))
                .foregroundStyle(.secondary)

            // One Text so the greeting wraps as a sentence at large type sizes
            (Text(greetingText + " ")
                .font(Constants.Typography.display(28, weight: .regular))
                .foregroundStyle(Constants.Colors.primaryColor)
             + Text(userName)
                .font(Constants.Typography.displayItalic(28))
                .foregroundStyle(Constants.Colors.accentGold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Constants.Colors.cardBackground))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
        .padding(.top, 8)
    }

    // MARK: - Daily Ritual Hero Card

    private var dailyRitualHeroCard: some View {
        Group {
            if let service = dailySuggestionService, let suggestion = service.suggestion {
                VStack(alignment: .leading, spacing: 0) {
                    // The brewer for today's method, drawn with the anatomy kit (Design/figures/objects)
                    if !typeSize.isAccessibilitySize {
                        Image(categoryFigure(for: suggestion.technique))
                            .resizable()
                            .scaledToFit()
                            .frame(height: 172)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(Constants.Colors.primaryColor.opacity(0.03))
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Today’s ritual")
                            Spacer()
                            if suggestion.streakDays > 0 {
                                Text("\(suggestion.streakDays)-day streak")
                            }
                        }
                        .font(Constants.Typography.sans(13, weight: .medium))
                        .foregroundStyle(Constants.Colors.accentGold)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.technique.name)
                                .font(Constants.Typography.display(28, weight: .regular))
                                .foregroundStyle(Constants.Colors.primaryColor)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(suggestion.flavourHook)
                                .font(Constants.Typography.displayItalic(16))
                                .foregroundStyle(Constants.Colors.accentGold)
                        }

                        specsGrid(for: suggestion.technique)

                        KButton(
                            title: "Begin brewing",
                            variant: .gold,
                            action: {
                                service.recordSuggestionBrew()
                                navigationPath.append(suggestion.technique)
                            }
                        )
                    }
                    .padding(20)
                }
                .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous))
                .elevatedCardStyle()
                .padding(.horizontal, Constants.Layout.horizontalPadding)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(Constants.Animation.standard, value: dailySuggestionService?.suggestion?.technique.techniqueId)
    }

    private func categoryFigure(for technique: Technique) -> String {
        switch appEnvironment.databaseService.method(byId: technique.methodId)?.category {
        case "Immersion": return "figure_cat_immersion"
        case "Pressure": return "figure_cat_pressure"
        case "Cold Brew": return "figure_cat_cold_brew"
        case "Stovetop & Traditional": return "figure_cat_stovetop"
        case "Machine": return "figure_cat_machine"
        default: return "figure_cat_pour_over"
        }
    }

    private func specsGrid(for technique: Technique) -> some View {
        let minutes = technique.totalTimeSeconds / 60
        let seconds = technique.totalTimeSeconds % 60
        let timeString = "\(minutes):\(String(format: "%02d", seconds))"
        let ratioString = "1:\(String(format: "%.0f", technique.ratioWaterCoffee))"

        let columns = [
            specColumn(label: "Time", value: timeString),
            specColumn(label: "Water", value: "\(technique.waterTempC)°C"),
            specColumn(label: "Ratio", value: ratioString),
            specColumn(label: "Grind", value: technique.grindSizeLabel),
        ]

        return Group {
            if typeSize.isAccessibilitySize {
                // Four columns don't fit at accessibility sizes: two rows of two
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) { columns[0]; columns[1] }
                    HStack(spacing: 8) { columns[2]; columns[3] }
                }
            } else {
                HStack(spacing: 8) { columns[0]; columns[1]; columns[2]; columns[3] }
            }
        }
        .padding(.top, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Constants.Colors.primaryColor.opacity(0.08)).frame(height: 0.5)
        }
    }

    private func specColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Constants.Typography.sans(12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(Constants.Typography.sans(16, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Constants.Colors.primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func initDailySuggestionIfNeeded() {
        guard dailySuggestionService == nil else {
            dailySuggestionService?.refreshIfNeeded()
            return
        }
        let service = DailySuggestionService(
            databaseService: appEnvironment.databaseService,
            context: managedObjectContext,
            ownedMethodIds: Set(appEnvironment.userGearRaw.split(separator: ",").map(String.init)),
            level: appEnvironment.userLevel
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Constants.Colors.accentGold.opacity(0.10))
                        .frame(width: 44, height: 44)

                    Image(systemName: "viewfinder")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Constants.Colors.accentGold)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Bean First")
                        .font(Constants.Typography.sans(15, weight: .semibold))
                        .foregroundStyle(Constants.Colors.primaryColor)

                    Text("Scan a bag and get techniques that suit it")
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
            KSectionHeader(title: "Browse methods")
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
                    .font(Constants.Typography.sans(13))
                    .foregroundStyle(.secondary)
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
