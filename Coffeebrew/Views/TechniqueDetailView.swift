import SwiftUI

struct TechniqueDetailView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    let technique: Technique
    var onBeginBrewing: (() -> Void)? = nil

    private var categoryName: String {
        appEnvironment.databaseService.method(byId: technique.methodId)?.category ?? ""
    }

    private var brandName: String {
        appEnvironment.databaseService.method(byId: technique.methodId)?.name ?? ""
    }

    private var categoryTint: Color {
        Constants.CategoryTints.tint(for: categoryName)
    }

    private var steps: [BrewStep] {
        appEnvironment.databaseService.steps(forTechniqueId: technique.techniqueId)
    }

    private var formattedTime: String {
        let mins = technique.totalTimeSeconds / 60
        let secs = technique.totalTimeSeconds % 60
        if secs > 0 {
            return "\(mins):\(String(format: "%02d", secs))"
        }
        return "\(mins):00"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    heroArea
                    infoCard
                        .padding(.top, -20)
                    parametersGrid
                        .padding(.top, 24)
                        .padding(.horizontal, Constants.Layout.horizontalPadding)
                    stepsPreview
                        .padding(.top, 28)
                        .padding(.horizontal, Constants.Layout.horizontalPadding)
                    // Bottom spacer for sticky CTA
                    Spacer()
                        .frame(height: 120)
                }
            }

            // Sticky bottom CTA
            stickyBottomCTA
        }
        .adaptiveBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero Area

    private var heroArea: some View {
        ZStack {
            // Gradient background using category tint
            LinearGradient(
                colors: [categoryTint.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle radial gradient overlay
            RadialGradient(
                colors: [categoryTint.opacity(0.05), Color.clear],
                center: .center,
                startRadius: 40,
                endRadius: 200
            )

            // Technique image
            Image(technique.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 240, height: 240)
        }
        .frame(height: 360)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            KEyebrow(
                text: "\(categoryName) \u{00B7} \(brandName)".uppercased(),
                color: categoryTint
            )

            Text(technique.name)
                .font(Constants.Typography.display(38))
                .foregroundStyle(Constants.Colors.primaryColor)

            if let notes = technique.deepDive?.tastingNotes, !notes.isEmpty {
                Text(notes)
                    .font(Constants.Typography.displayItalic(15))
                    .foregroundStyle(Constants.Colors.accentGold)
            }

            Text(technique.description)
                .font(Constants.Typography.sans(15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Constants.Layout.horizontalPadding)
        .padding(.top, 24)
        .background(Constants.Colors.background)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: Constants.Layout.cornerRadius,
                topTrailingRadius: Constants.Layout.cornerRadius
            )
        )
    }

    // MARK: - Parameters Grid

    private var parametersGrid: some View {
        let gridItems = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
        return LazyVGrid(columns: gridItems, spacing: 10) {
            parameterCell(
                icon: "clock",
                label: "TIME",
                value: formattedTime
            )
            parameterCell(
                icon: "thermometer.medium",
                label: "TEMP",
                value: "\(technique.waterTempC)\u{00B0}C"
            )
            parameterCell(
                icon: "scalemass",
                label: "RATIO",
                value: "1:\(String(format: "%.0f", technique.ratioWaterCoffee))"
            )
            parameterCell(
                icon: "circle.grid.3x3",
                label: "GRIND",
                value: technique.grindSizeLabel
            )
        }
    }

    private func parameterCell(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(Constants.Typography.mono(9))
                    .textCase(.uppercase)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(Constants.Typography.mono(18))
                .foregroundStyle(Constants.Colors.primaryColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(Constants.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Steps Preview

    private var stepsPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            KEyebrow(
                text: "THE RITUAL \u{00B7} \(steps.count) STEPS",
                color: Constants.Colors.accentGold
            )

            VStack(spacing: 0) {
                ForEach(Array(steps.prefix(4).enumerated()), id: \.element.id) { index, step in
                    stepRow(step: step)

                    if index < min(3, steps.count - 1) {
                        Divider()
                            .padding(.leading, 36)
                    }
                }
            }
        }
    }

    private func stepRow(step: BrewStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", step.stepNumber))
                .font(Constants.Typography.mono(12))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.displayTitle)
                    .font(Constants.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(Constants.Colors.primaryColor)

                Text(step.instruction)
                    .font(Constants.Typography.sans(13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(step.durationSeconds > 0 ? "\(step.durationSeconds)s" : "\u{2014}")
                .font(Constants.Typography.mono(12))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Sticky Bottom CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.clear, Constants.Colors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 36)

            KButton(
                title: "Begin brewing",
                icon: "arrow.right",
                variant: .gold,
                action: { onBeginBrewing?() }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
            .background(Constants.Colors.background)
        }
    }
}
