import SwiftUI

struct BeansView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @StateObject private var viewModel = BeansViewModel()
    let technique: Technique

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                techniqueHeader

                // Deep dive section (collapsible)
                if let deepDive = technique.deepDive {
                    TechniqueDeepDiveSection(deepDive: deepDive)
                        .padding(.horizontal, Constants.Layout.horizontalPadding)
                }

                if viewModel.beans.isEmpty {
                    EmptyStateView(
                        icon: "leaf",
                        title: "No Bean Recommendations",
                        message: "No beans found for this technique. You can still proceed to brewing."
                    )
                } else {
                    beansList
                }
                continueButton
            }
            .padding(.vertical)
        }
        .adaptiveBackground()
        .navigationTitle("Bean Selection")
        .navigationBarTitleDisplayMode(.large)
        .task {
            viewModel.load(forTechniqueId: technique.techniqueId, from: appEnvironment.databaseService)
        }
    }

    private var techniqueHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hero photo if available
            if let photoName = technique.methodPhoto {
                Image(photoName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous))
                    .padding(.horizontal, Constants.Layout.horizontalPadding)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(technique.name)
                    .font(Constants.Typography.title)
                    .foregroundStyle(Constants.Colors.primaryColor)

                HStack(spacing: 16) {
                    Label("\(technique.waterTempC)\u{00B0}C", systemImage: "thermometer.medium")
                    Label(technique.grindSizeLabel, systemImage: "circle.grid.3x3")
                        .lineLimit(1)
                    Label(technique.totalTimeSeconds.formattedTime, systemImage: "clock")
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Constants.Layout.horizontalPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var beansList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Beans")
                .font(Constants.Typography.callout)
                .foregroundStyle(Constants.Colors.primaryColor)
                .padding(.horizontal, Constants.Layout.horizontalPadding)

            ForEach(viewModel.beans) { bean in
                BeanCardView(
                    bean: bean,
                    isSelected: viewModel.selectedBean?.beanId == bean.beanId
                ) {
                    withAnimation(Constants.Animation.standard) {
                        viewModel.selectedBean = bean
                    }
                    HapticsManager.shared.selection()
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
            }
        }
    }

    private var continueButton: some View {
        NavigationLink {
            ParametersView(technique: technique, selectedBean: viewModel.selectedBean)
        } label: {
            Text("Continue to Parameters")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                        .fill(Constants.Colors.accentGold)
                )
        }
        .accessibilityLabel("Continue to brewing parameters")
        .padding(.horizontal, Constants.Layout.horizontalPadding)
        .padding(.top, 8)
    }
}

// MARK: - Bean Card

struct BeanCardView: View {
    let bean: Bean
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bean.name)
                            .font(Constants.Typography.callout)
                            .foregroundStyle(Constants.Colors.primaryColor)
                        Text(bean.origin)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    matchScoreBadge
                }

                roastLevelBar

                HStack(spacing: 12) {
                    Label(bean.process, systemImage: "leaf.fill")
                    Label(bean.roastLevel, systemImage: "flame.fill")
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)

                flavourNotePills
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(isSelected
                        ? Constants.Colors.accentGold.opacity(0.06)
                        : Constants.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? Constants.Colors.accentGold : Color.clear,
                        lineWidth: isSelected ? 1.5 : 0
                    )
            )
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.03),
                radius: 8, x: 0, y: 2
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bean.name), \(bean.origin), \(bean.roastLevel) roast, match score \(bean.matchScore) percent")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var matchScoreBadge: some View {
        VStack(spacing: 2) {
            Text("\(bean.matchScore)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor)
            Text("match")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(width: 44, height: 44)
        .background(Circle().fill(scoreColor.opacity(0.08)))
    }

    private var scoreColor: Color {
        switch bean.matchScore {
        case 80...100: return .green
        case 60..<80: return Constants.Colors.accentGold
        default: return .orange
        }
    }

    private var roastLevelBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Constants.Colors.primaryColor.opacity(0.06))
                RoundedRectangle(cornerRadius: 3)
                    .fill(roastGradient)
                    .frame(width: geo.size.width * roastFraction)
            }
        }
        .frame(height: 4)
    }

    private var roastFraction: Double {
        switch bean.roastLevel.lowercased() {
        case "light": return 0.2
        case "light-medium": return 0.35
        case "medium": return 0.5
        case "medium-dark": return 0.7
        case "dark": return 0.9
        default: return 0.5
        }
    }

    private var roastGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xC8A96E), Color(hex: 0x6B3A2A), Color(hex: 0x2C1810)],
            startPoint: .leading, endPoint: .trailing
        )
    }

    private var flavourNotePills: some View {
        FlowLayout(spacing: 6) {
            ForEach(bean.flavourNotes, id: \.self) { note in
                Text(note)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Constants.Colors.accentGold.opacity(0.08)))
            }
        }
    }
}
