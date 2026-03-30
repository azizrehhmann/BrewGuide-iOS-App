import SwiftUI

struct GrindDetailView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    let technique: Technique

    private var grindSize: GrindSize? {
        guard let ref = technique.grindSizeRef else { return nil }
        return appEnvironment.databaseService.grindSize(forLevel: ref)
    }

    private var allGrindSizes: [GrindSize] {
        appEnvironment.databaseService.grindSizes
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                techniqueGrindHeader
                if let grind = grindSize {
                    grindDetailCards(grind)
                    grindScaleVisual(grind)
                }
                allGrindSizesSection
            }
            .padding(.vertical)
        }
        .adaptiveBackground()
        .navigationTitle("Grind Size")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Technique Grind Header

    private var techniqueGrindHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "circle.grid.3x3.fill")
                .font(.system(size: 36))
                .foregroundStyle(Constants.Colors.accentGold)

            Text(technique.grindSizeLabel)
                .font(.system(.title2, design: .default, weight: .bold))
                .foregroundStyle(Constants.Colors.primaryColor)
                .multilineTextAlignment(.center)

            Text("for \(technique.name)")
                .font(Constants.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Detail Cards

    private func grindDetailCards(_ grind: GrindSize) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            grindInfoCard(
                icon: "ruler",
                title: "Particle Size",
                value: grind.particleSizeUm,
                unit: "µm"
            )
            grindInfoCard(
                icon: "gearshape",
                title: "EK43 Scale",
                value: grind.ek43Range,
                unit: ""
            )
            grindInfoCard(
                icon: "dial.low",
                title: "Comandante",
                value: grind.comandanteClicks,
                unit: "clicks"
            )
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private func grindInfoCard(icon: String, title: String, value: String, unit: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Constants.Colors.accentGold)

            Text(value)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(Constants.Colors.primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(unit.isEmpty ? " " : unit)
                .font(.caption2)
                .foregroundStyle(unit.isEmpty ? .clear : .secondary)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit)")
    }

    // MARK: - Texture Description

    private func grindScaleVisual(_ activeGrind: GrindSize) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Feels Like")
                .font(Constants.Typography.headline)
                .foregroundStyle(Constants.Colors.primaryColor)

            HStack(spacing: 12) {
                Image(systemName: "hand.point.up.fill")
                    .font(.title2)
                    .foregroundStyle(Constants.Colors.accentGold)

                Text(activeGrind.texture)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(Constants.Colors.primaryColor)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Constants.Colors.accentGold.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Constants.Colors.accentGold.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Full Grind Reference

    private var allGrindSizesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All Grind Sizes")
                .font(Constants.Typography.headline)
                .foregroundStyle(Constants.Colors.primaryColor)
                .padding(.horizontal, Constants.Layout.horizontalPadding)

            VStack(spacing: 0) {
                // Header row
                grindTableHeader

                ForEach(Array(allGrindSizes.enumerated()), id: \.element.id) { index, grind in
                    Divider()
                    grindTableRow(grind, isActive: grind.level == grindSize?.level, isLast: index == allGrindSizes.count - 1)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            )
            .padding(.horizontal, Constants.Layout.horizontalPadding)
        }
    }

    private var grindTableHeader: some View {
        HStack(spacing: 0) {
            Text("Level")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("µm")
                .frame(width: 70, alignment: .center)
            Text("EK43")
                .frame(width: 50, alignment: .center)
            Text("Clicks")
                .frame(width: 50, alignment: .center)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func grindTableRow(_ grind: GrindSize, isActive: Bool, isLast: Bool) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                if isActive {
                    Circle()
                        .fill(Constants.Colors.accentGold)
                        .frame(width: 6, height: 6)
                }
                Text(LocalizedStringKey(grind.level))
                    .font(.caption.weight(isActive ? .bold : .regular))
                    .foregroundStyle(isActive ? Constants.Colors.accentGold : Constants.Colors.primaryColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(grind.particleSizeUm)
                .frame(width: 70, alignment: .center)

            Text(grind.ek43Range)
                .frame(width: 50, alignment: .center)

            Text(grind.comandanteClicks)
                .frame(width: 50, alignment: .center)
        }
        .font(.caption)
        .foregroundStyle(isActive ? Constants.Colors.primaryColor : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isActive ? Constants.Colors.accentGold.opacity(0.06) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(grind.level), \(grind.particleSizeUm) microns, EK43 \(grind.ek43Range), Comandante \(grind.comandanteClicks) clicks\(isActive ? ", current setting" : "")")
    }
}
