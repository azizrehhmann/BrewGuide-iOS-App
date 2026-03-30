import SwiftUI

struct BeanRecommendationsView: View {
    @ObservedObject var viewModel: BeanFirstViewModel
    let beanProfile: BeanProfile
    let onBrewTechnique: (Technique) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                beanHeader

                if let response = viewModel.recommendations {
                    if !response.summary.isEmpty {
                        summaryCard(response.summary)
                    }

                    ForEach(response.recommendations) { rec in
                        RecommendationCard(
                            recommendation: rec,
                            technique: viewModel.technique(for: rec),
                            onBrew: {
                                if let technique = viewModel.technique(for: rec) {
                                    onBrewTechnique(technique)
                                }
                            }
                        )
                    }
                } else {
                    ProgressView("Loading recommendations...")
                        .padding(.top, 40)
                }

                Button {
                    viewModel.reset()
                } label: {
                    Text("Try Another Bean")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(Constants.Colors.accentGold)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .padding(.vertical)
        }
        .adaptiveBackground()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.reset()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Constants.Colors.primaryColor)
                }
            }
        }
    }

    // MARK: - Bean Header

    private var beanHeader: some View {
        VStack(spacing: 6) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Constants.Colors.accentGold)

            Text(beanProfile.name)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Constants.Colors.primaryColor)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                if let origin = beanProfile.origin {
                    tagPill(origin)
                }
                if let roast = beanProfile.roastLevel {
                    tagPill(roast)
                }
                if let process = beanProfile.process {
                    tagPill(process)
                }
            }

            if !beanProfile.flavourNotes.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(beanProfile.flavourNotes, id: \.self) { note in
                        Text(note)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Constants.Colors.accentGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Constants.Colors.accentGold.opacity(0.08)))
                    }
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
            }
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private func tagPill(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Constants.Colors.primaryColor.opacity(0.06))
            )
    }

    // MARK: - Summary Card

    private func summaryCard(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Constants.Colors.accentGold)

            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                .fill(Constants.Colors.accentGold.opacity(0.06))
        )
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let recommendation: TechniqueRecommendation
    let technique: Technique?
    let onBrew: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(rankColor.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Text("#\(recommendation.rank)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(rankColor)
                }

                if let technique {
                    Image(technique.imageName)
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.techniqueName)
                        .font(Constants.Typography.callout)
                        .foregroundStyle(Constants.Colors.primaryColor)

                    Text(recommendation.equipmentName)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(spacing: 1) {
                    Text("\(recommendation.matchScore)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)

                    Text("match")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Constants.Colors.accentGold)
                Text(recommendation.keyBenefit)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Constants.Colors.accentGold)
            }

            Text(recommendation.reasoning)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(4)

            if !recommendation.warnings.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)

                    Text(recommendation.warnings.joined(separator: " · "))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.8))
                }
            }

            HStack {
                Spacer()
                Button(action: onBrew) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Brew with this")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Constants.Colors.accentGold)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                .fill(Constants.Colors.cardBackground)
        )
        .shadow(
            color: colorScheme == .dark ? .clear : .black.opacity(0.03),
            radius: 10, x: 0, y: 2
        )
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private var rankColor: Color {
        switch recommendation.rank {
        case 1: return Constants.Colors.accentGold
        case 2: return .orange
        case 3: return .mint
        default: return .secondary
        }
    }

    private var scoreColor: Color {
        switch recommendation.matchScore {
        case 80...100: return .green
        case 60..<80: return Constants.Colors.accentGold
        default: return .orange
        }
    }
}
