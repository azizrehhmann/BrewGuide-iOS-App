import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategory: String = "All"
    @State private var searchText: String = ""

    private var allCategories: [String] {
        ["All"] + appEnvironment.databaseService.categories
    }

    private var allTechniques: [Technique] {
        appEnvironment.databaseService.techniques
    }

    private var filteredTechniques: [Technique] {
        var list = allTechniques
        if selectedCategory != "All" {
            let methods = appEnvironment.databaseService.methods(forCategory: selectedCategory)
            let methodIds = Set(methods.map { $0.methodId })
            list = list.filter { methodIds.contains($0.methodId) }
        }
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.description.localizedCaseInsensitiveContains(searchText) }
        }
        return list
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    KEyebrow(text: "\(allTechniques.count) techniques")

                    (Text("Every way to\n")
                        .font(Constants.Typography.display(40))
                     + Text("brew a cup.")
                        .font(Constants.Typography.displayItalic(40))
                        .foregroundColor(Constants.Colors.accentGold))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .lineSpacing(-4)
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 16)

                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Constants.Colors.primaryColor.opacity(0.35))
                    TextField("Search techniques", text: $searchText)
                        .font(Constants.Typography.sans(14))
                        .foregroundStyle(Constants.Colors.primaryColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Constants.Colors.primaryColor.opacity(0.06))
                )
                .padding(.horizontal, Constants.Layout.horizontalPadding)
                .padding(.bottom, 14)

                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(allCategories, id: \.self) { cat in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = cat
                                }
                            } label: {
                                Text(cat)
                                    .font(Constants.Typography.sans(12, weight: .semibold))
                                    .tracking(0.2)
                                    .foregroundStyle(selectedCategory == cat ? Constants.Colors.background : Constants.Colors.primaryColor)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedCategory == cat
                                            ? Constants.Colors.primaryColor
                                            : Constants.Colors.cardBackground,
                                        in: Capsule()
                                    )
                                    .overlay(
                                        selectedCategory != cat
                                            ? Capsule().strokeBorder(Constants.Colors.primaryColor.opacity(0.08), lineWidth: 0.5)
                                            : nil
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Constants.Layout.horizontalPadding)
                }
                .padding(.bottom, 18)

                // Technique cards
                VStack(spacing: 12) {
                    ForEach(filteredTechniques) { technique in
                        NavigationLink(value: technique) {
                            LibraryTechniqueCard(technique: technique)
                        }
                        .buttonStyle(.scale)
                    }
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
            }
        }
        .adaptiveBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Technique.self) { technique in
            BeansView(technique: technique)
        }
    }
}

// MARK: - Library Technique Card

struct LibraryTechniqueCard: View {
    let technique: Technique
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize

    private var categoryName: String {
        appEnvironment.databaseService.method(byId: technique.methodId)?.category ?? ""
    }

    private var categoryTint: Color {
        Constants.CategoryTints.tint(for: categoryName)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Image panel (dropped at accessibility sizes so the text gets the width)
            if !typeSize.isAccessibilitySize {
            ZStack {
                Constants.Colors.primaryColor.opacity(0.03)
                Image(technique.imageName)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
            }
            .frame(width: 96)
            }

            // Info
            VStack(alignment: .leading, spacing: 0) {
                (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .top))) {
                    VStack(alignment: .leading, spacing: 3) {
                        KEyebrow(text: categoryName, color: categoryTint)
                        Text(technique.name)
                            .font(Constants.Typography.display(20))
                            .foregroundStyle(Constants.Colors.primaryColor)
                    }
                    Spacer(minLength: 8)
                    Text(technique.totalTimeSeconds.shortFormattedTime)
                        .font(Constants.Typography.sans(15))
                        .foregroundStyle(Constants.Colors.primaryColor)
                        .monospacedDigit()
                        .fixedSize()
                }

                Text(technique.description)
                    .font(Constants.Typography.sans(12).italic())
                    .foregroundStyle(Constants.Colors.accentGold)
                    .lineLimit(1)
                    .padding(.top, 4)

                // One Text so a long grind label wraps as a sentence instead of splitting the row
                Text("\(technique.waterTempC)\u{00B0}C, 1:\(String(format: "%.0f", technique.ratioWaterCoffee)), \(technique.grindSizeLabel.lowercased()) grind")
                .font(Constants.Typography.sans(13))
                .monospacedDigit()
                .multilineTextAlignment(.leading)
                .foregroundStyle(Constants.Colors.primaryColor.opacity(0.5))
                .padding(.top, 8)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .background(Constants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark ? Constants.Shadows.darkBorderColor : .black.opacity(0.04),
                    lineWidth: 0.5
                )
        )
        .shadow(
            color: colorScheme == .dark ? .clear : Constants.Shadows.cardColor,
            radius: Constants.Shadows.cardRadius, x: 0, y: Constants.Shadows.cardY
        )
    }
}
