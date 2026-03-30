import SwiftUI
import CoreData

struct HomeView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var showSettings = false
    @State private var showJournal = false
    @State private var showBeanInventory = false
    @State private var showTechniqueSearch = false
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
                VStack(spacing: 28) {
                    headerSection
                    dailySuggestionSection
                    beanFirstCard
                    favouritesRecentsSection
                    techniqueSpotlightSection
                    beanInventoryPreview
                    brewMethodsSection
                }
                .padding(.vertical, 8)
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
            .navigationDestination(isPresented: $showJournal) {
                BrewJournalView(context: managedObjectContext)
            }
            .navigationDestination(isPresented: $showBeanInventory) {
                BeanInventoryView(context: managedObjectContext)
            }
            .navigationDestination(isPresented: $showTechniqueSearch) {
                TechniqueSearchView()
            }
            .navigationDestination(isPresented: $showBeanFirst) {
                BeanFirstEntryView(
                    databaseService: appEnvironment.databaseService,
                    onBrewTechnique: { technique in
                        // Dismiss Bean First, then navigate to technique
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

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("BrewGuide")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .accessibilityAddTraits(.isHeader)
                Text("Your coffee brewing companion")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                headerButton(icon: "magnifyingglass", label: "Search Techniques") {
                    showTechniqueSearch = true
                }
                headerButton(icon: "book.closed", label: "Brew Journal") {
                    showJournal = true
                }
                headerButton(icon: "gearshape", label: "Settings") {
                    showSettings = true
                }
                profileButton
            }
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private func headerButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Constants.Colors.primaryColor.opacity(0.6))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Constants.Colors.primaryColor.opacity(0.06))
                )
        }
        .accessibilityLabel(label)
    }

    private var profileButton: some View {
        Button { showProfile = true } label: {
            if authService.isSignedIn, let profile = authService.userProfile {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Constants.Colors.accentGold, Constants.Colors.accentGold.opacity(0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Text(profile.initials)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Constants.Colors.primaryColor.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Constants.Colors.primaryColor.opacity(0.06)))
            }
        }
        .accessibilityLabel(authService.isSignedIn ? "Profile" : "Sign in")
    }

    // MARK: - Daily Suggestion

    private var dailySuggestionSection: some View {
        Group {
            if let service = dailySuggestionService, let suggestion = service.suggestion {
                DailySuggestionCardView(suggestion: suggestion) {
                    service.recordSuggestionBrew()
                    navigationPath.append(suggestion.technique)
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(Constants.Animation.standard, value: dailySuggestionService?.suggestion?.technique.techniqueId)
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
                    RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
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

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bean First")
                        .font(Constants.Typography.callout)
                        .foregroundStyle(.primary)

                    Text("Scan a bag or pick a bean for AI recommendations")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.quaternary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Constants.Layout.horizontalPadding)
        .accessibilityLabel("Bean First. Scan a coffee bag or pick a bean for AI-powered technique recommendations.")
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
                        // Quick re-brew: navigate directly to ParametersView
                        // by going through BeansView (the technique nav destination)
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

    // MARK: - Technique Spotlight (Deep Dive Discovery)

    /// Picks a random technique that has deep-dive content, rotating daily.
    private var spotlightTechnique: Technique? {
        let withDeepDive = appEnvironment.databaseService.techniques.filter { $0.deepDive != nil }
        guard !withDeepDive.isEmpty else { return nil }
        // Deterministic daily rotation based on day-of-year
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

    // MARK: - Bean Inventory Preview

    private var beanInventoryPreview: some View {
        BeanInventoryPreviewCard(context: managedObjectContext) {
            showBeanInventory = true
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Brew Methods Section

    private var brewMethodsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Brew Methods")
                    .font(Constants.Typography.title)
                    .foregroundStyle(Constants.Colors.primaryColor)
                Text("Select a guide to start")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Constants.Layout.horizontalPadding)
            .accessibilityAddTraits(.isHeader)

            if categories.isEmpty {
                EmptyStateView(
                    icon: "cup.and.saucer",
                    title: "No Methods Found",
                    message: "Brewing method data could not be loaded."
                )
            } else {
                categoryGrid
            }
        }
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(categories, id: \.self) { category in
                NavigationLink(value: category) {
                    CategoryCardView(
                        category: category,
                        methodCount: appEnvironment.databaseService.methods(forCategory: category).count
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }
}

// MARK: - Category Card

struct CategoryCardView: View {
    let category: String
    let methodCount: Int
    @Environment(\.colorScheme) private var colorScheme

    private var categoryIcon: String {
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

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Constants.Colors.accentGold.opacity(colorScheme == .dark ? 0.12 : 0.08))
                    .frame(width: 56, height: 56)

                Image(systemName: categoryIcon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Constants.Colors.accentGold)
            }

            VStack(spacing: 3) {
                Text(LocalizedStringKey(category))
                    .font(Constants.Typography.callout)
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text("\(methodCount) method\(methodCount == 1 ? "" : "s")")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                .fill(Constants.Colors.cardBackground)
        )
        .shadow(
            color: colorScheme == .dark ? .clear : .black.opacity(0.03),
            radius: 10, x: 0, y: 2
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category), \(methodCount) method\(methodCount == 1 ? "" : "s")")
        .accessibilityHint("Double tap to browse \(category.lowercased()) equipment")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Bean Inventory Preview Card

struct BeanInventoryPreviewCard: View {
    @Environment(\.managedObjectContext) private var context
    @State private var viewModel: BeanInventoryViewModel?
    let onTap: () -> Void

    init(context: NSManagedObjectContext, onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    var body: some View {
        Group {
            if let viewModel {
                BeanInventoryPreviewContent(viewModel: viewModel, onTap: onTap)
            } else {
                // Placeholder with same layout so it doesn't jump
                Button(action: onTap) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
                                .fill(Constants.Colors.accentGold.opacity(0.08))
                                .frame(width: 44, height: 44)
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Constants.Colors.accentGold)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Coffee Beans")
                                .font(Constants.Typography.callout)
                                .foregroundStyle(.primary)
                            Text("Track your bean inventory")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                            .fill(Constants.Colors.cardBackground)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = BeanInventoryViewModel(context: context)
            } else {
                viewModel?.fetchBeans()
            }
        }
    }
}

private struct BeanInventoryPreviewContent: View {
    @ObservedObject var viewModel: BeanInventoryViewModel
    let onTap: () -> Void

    private var activeBeanCount: Int { viewModel.activeBeanCount }
    private var previewBeans: [CoffeeBean] { Array(viewModel.filteredBeans.prefix(3)) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
                        .fill(Constants.Colors.accentGold.opacity(0.08))
                        .frame(width: 44, height: 44)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Constants.Colors.accentGold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Coffee Beans")
                        .font(Constants.Typography.callout)
                        .foregroundStyle(.primary)

                    if activeBeanCount > 0 {
                        Text("\(activeBeanCount) bag\(activeBeanCount == 1 ? "" : "s") in pantry")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Track your bean inventory")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if !previewBeans.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(previewBeans, id: \.objectID) { bean in
                            BeanProgressRing(
                                remaining: bean.remainingWeightGrams,
                                total: bean.totalWeightGrams,
                                ringSize: 32
                            )
                            .background(
                                Circle()
                                    .fill(Constants.Colors.cardBackground)
                                    .frame(width: 36, height: 36)
                            )
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.quaternary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Coffee Beans, \(activeBeanCount) bags. Tap to manage inventory.")
    }
}
