import SwiftUI

struct EquipmentListView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    let category: String

    private var methods: [BrewMethod] {
        appEnvironment.databaseService.methods(forCategory: category)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if methods.isEmpty {
                    EmptyStateView(
                        icon: "cup.and.saucer",
                        title: "No Equipment",
                        message: "No brewing equipment found in this category."
                    )
                } else {
                    ForEach(methods) { method in
                        NavigationLink(value: method) {
                            EquipmentRowView(method: method, techniqueCount: techniqueCount(for: method))
                        }
                        .buttonStyle(.scale)
                    }
                }
            }
            .padding(.horizontal, Constants.Layout.horizontalPadding)
            .padding(.vertical)
        }
        .adaptiveBackground()
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.large)
    }

    private func techniqueCount(for method: BrewMethod) -> Int {
        appEnvironment.databaseService.techniques(forMethodId: method.methodId).count
    }
}

// MARK: - Equipment Row

struct EquipmentRowView: View {
    let method: BrewMethod
    let techniqueCount: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            Image(method.techniqueImageName)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(method.name)
                    .font(Constants.Typography.callout)
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .lineLimit(1)

                Text(method.description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    difficultyLabel
                    Text("\(techniqueCount) technique\(techniqueCount == 1 ? "" : "s")")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
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
        .accessibilityLabel("\(method.name), \(method.difficultyLabel) difficulty, \(techniqueCount) technique\(techniqueCount == 1 ? "" : "s")")
        .accessibilityHint("Double tap to view techniques")
        .accessibilityAddTraits(.isButton)
    }

    private var difficultyLabel: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= method.difficulty ? Constants.Colors.accentGold : Constants.Colors.primaryColor.opacity(0.1))
                    .frame(width: 5, height: 5)
            }
            Text(method.difficultyLabel)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}
