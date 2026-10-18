import SwiftUI

struct TechniqueSearchView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedCategory: String?
    @State private var selectedDifficulty: Int?
    @State private var selectedGrind: String?
    @State private var sortOption: SortOption = .name
    @State private var searchTask: Task<Void, Never>?

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case time = "Brew Time"
        case temperature = "Temperature"
    }

    private var allItems: [(technique: Technique, method: BrewMethod)] {
        appEnvironment.databaseService.allTechniquesWithMethod
    }

    private var categories: [String] {
        appEnvironment.databaseService.categories
    }

    private var grindOptions: [String] {
        let labels = Set(allItems.map { shortGrind($0.technique.grindSizeLabel) })
        return labels.sorted()
    }

    private var filteredItems: [(technique: Technique, method: BrewMethod)] {
        var results = allItems

        if !debouncedSearchText.isEmpty {
            let query = debouncedSearchText.lowercased()
            results = results.filter {
                $0.technique.name.lowercased().contains(query) ||
                $0.technique.description.lowercased().contains(query) ||
                $0.method.name.lowercased().contains(query) ||
                $0.method.category.lowercased().contains(query)
            }
        }

        if let category = selectedCategory {
            results = results.filter { $0.method.category == category }
        }

        if let difficulty = selectedDifficulty {
            results = results.filter { $0.method.difficulty == difficulty }
        }

        if let grind = selectedGrind {
            results = results.filter { shortGrind($0.technique.grindSizeLabel) == grind }
        }

        switch sortOption {
        case .name:
            break
        case .time:
            results.sort { $0.technique.totalTimeSeconds < $1.technique.totalTimeSeconds }
        case .temperature:
            results.sort { $0.technique.waterTempC < $1.technique.waterTempC }
        }

        return results
    }

    private var activeFilterCount: Int {
        [selectedCategory != nil, selectedDifficulty != nil, selectedGrind != nil].filter { $0 }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                searchBar
                filterChips
                sortPicker
                resultsList
            }
            .padding(.vertical)
        }
        .adaptiveBackground()
        .navigationTitle("Search Techniques")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            if newValue.isEmpty {
                debouncedSearchText = ""
            } else {
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
                    guard !Task.isCancelled else { return }
                    debouncedSearchText = newValue
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tertiary)
            TextField("Search techniques, methods...", text: $searchText)
                .font(.system(.body, design: .rounded))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
                .fill(Constants.Colors.cardBackground)
        )
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chipButton("All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(categories, id: \.self) { category in
                        chipButton(category, isSelected: selectedCategory == category) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { level in
                        let label = difficultyLabel(level)
                        chipButton(label, isSelected: selectedDifficulty == level) {
                            selectedDifficulty = selectedDifficulty == level ? nil : level
                        }
                    }

                    Divider().frame(height: 16)

                    ForEach(grindOptions, id: \.self) { grind in
                        chipButton(grind, isSelected: selectedGrind == grind) {
                            selectedGrind = selectedGrind == grind ? nil : grind
                        }
                    }
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
            }

            if activeFilterCount > 0 {
                Button {
                    withAnimation(Constants.Animation.spring) {
                        selectedCategory = nil
                        selectedDifficulty = nil
                        selectedGrind = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Clear filters")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(Constants.Colors.accentGold)
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
            }
        }
    }

    private func chipButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Constants.Animation.spring) { action() }
            HapticsManager.shared.selection()
        } label: {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(isSelected ? .white : Constants.Colors.primaryColor.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Constants.Colors.accentGold : Constants.Colors.cardBackground)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Sort

    private var sortPicker: some View {
        HStack {
            Text("\(filteredItems.count) technique\(filteredItems.count == 1 ? "" : "s")")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10))
                    Text(sortOption.rawValue)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                }
                .foregroundStyle(Constants.Colors.primaryColor.opacity(0.6))
            }
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Results

    private var resultsList: some View {
        LazyVStack(spacing: 10) {
            if filteredItems.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Results",
                    message: "Try adjusting your search or filters."
                )
            } else {
                ForEach(filteredItems, id: \.technique.id) { item in
                    NavigationLink(value: item.technique) {
                        TechniqueSearchCard(technique: item.technique, method: item.method)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Helpers

    private func shortGrind(_ label: String) -> String {
        if let range = label.range(of: " (") {
            return String(label[..<range.lowerBound])
        }
        return label
    }

    private func difficultyLabel(_ level: Int) -> String {
        switch level {
        case 1: return String(localized: "Beginner")
        case 2: return String(localized: "Easy")
        case 3: return String(localized: "Intermediate")
        case 4: return String(localized: "Advanced")
        case 5: return String(localized: "Expert")
        default: return String(localized: "Unknown")
        }
    }
}

// MARK: - Search Result Card

struct TechniqueSearchCard: View {
    let technique: Technique
    let method: BrewMethod
    @Environment(\.colorScheme) private var colorScheme

    private var shortGrind: String {
        if let range = technique.grindSizeLabel.range(of: " (") {
            return String(technique.grindSizeLabel[..<range.lowerBound])
        }
        return technique.grindSizeLabel
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(technique.imageName)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(technique.name)
                            .font(Constants.Typography.callout)
                            .foregroundStyle(Constants.Colors.primaryColor)
                        Text(method.name)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(technique.totalTimeSeconds.formattedTime)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(Constants.Colors.accentGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Constants.Colors.accentGold.opacity(0.1))
                        .clipShape(Capsule())
                }

                HStack(spacing: 14) {
                    Label("\(technique.waterTempC)\u{00B0}C", systemImage: "thermometer.medium")
                    Label("1:\(String(format: "%.1f", technique.ratioWaterCoffee))", systemImage: "scalemass")
                    Label(shortGrind, systemImage: "circle.grid.3x3")
                        .lineLimit(1)
                    Spacer()
                    Text(LocalizedStringKey(method.category))
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(Constants.Colors.accentGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Constants.Colors.accentGold.opacity(0.08))
                        )
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                .fill(Constants.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark ? Constants.Shadows.darkBorderColor : .black.opacity(0.04),
                    lineWidth: colorScheme == .dark ? Constants.Shadows.darkBorderWidth : 0.5
                )
        )
        .shadow(
            color: colorScheme == .dark ? .clear : Constants.Shadows.cardColor,
            radius: Constants.Shadows.cardRadius, x: 0, y: Constants.Shadows.cardY
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(technique.name), \(method.name), \(technique.totalTimeSeconds.formattedTime)")
        .accessibilityHint("Double tap to view technique")
    }
}
