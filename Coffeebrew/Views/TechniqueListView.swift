import SwiftUI

struct TechniqueListView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    let method: BrewMethod

    private var techniques: [Technique] {
        appEnvironment.databaseService.techniques(forMethodId: method.methodId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if techniques.isEmpty {
                    EmptyStateView(
                        icon: "list.bullet.rectangle",
                        title: "No Techniques",
                        message: "No brewing techniques found for \(method.name)."
                    )
                } else {
                    ForEach(techniques) { technique in
                        NavigationLink(value: technique) {
                            TechniqueRowView(technique: technique)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Constants.Layout.horizontalPadding)
            .padding(.vertical)
        }
        .adaptiveBackground()
        .navigationTitle(method.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Technique Row

struct TechniqueRowView: View {
    let technique: Technique
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    private var isAccessibilitySize: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(technique.imageName)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                if isAccessibilitySize {
                    Text(technique.name)
                        .font(Constants.Typography.callout)
                        .foregroundStyle(Constants.Colors.primaryColor)
                    timeBadge
                } else {
                    HStack {
                        Text(technique.name)
                            .font(Constants.Typography.callout)
                            .foregroundStyle(Constants.Colors.primaryColor)
                        Spacer()
                        timeBadge
                    }
                }

                Text(technique.description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)

                if technique.deepDive != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Deep Dive Inside")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(Constants.Colors.accentGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Constants.Colors.accentGold.opacity(0.1))
                    )
                }

                Group {
                    if isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 6) {
                            detailLabels
                        }
                    } else {
                        HStack(spacing: 12) {
                            detailLabels
                        }
                    }
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                .fill(Constants.Colors.cardBackground)
        )
        .shadow(
            color: colorScheme == .dark ? .clear : .black.opacity(0.03),
            radius: 8, x: 0, y: 2
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to view bean recommendations")
    }

    @ViewBuilder
    private var detailLabels: some View {
        Label("\(technique.waterTempC)\u{00B0}C", systemImage: "thermometer.medium")
        Label("1:\(String(format: "%.1f", technique.ratioWaterCoffee))", systemImage: "scalemass")
        Label(technique.grindSizeLabel, systemImage: "circle.grid.3x3")
            .lineLimit(1)
    }

    private var timeBadge: some View {
        Text(technique.totalTimeSeconds.formattedTime)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(Constants.Colors.accentGold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Constants.Colors.accentGold.opacity(0.1))
            .clipShape(Capsule())
    }

    private var accessibilityDescription: String {
        "\(technique.name), \(technique.totalTimeSeconds.formattedTime), \(technique.waterTempC) degrees, ratio 1 to \(String(format: "%.0f", technique.ratioWaterCoffee)), \(technique.grindSizeLabel) grind"
    }
}
