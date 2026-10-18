import SwiftUI

/// A compact discovery card for the HomeView that teases a technique's deep-dive content.
/// Rotates daily to surface different techniques and encourage exploration.
struct TechniqueSpotlightCard: View {
    let technique: Technique
    let deepDive: TechniqueDeepDive
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                HapticsManager.shared.selection()
            } label: {
                headerContent
            }
            .buttonStyle(.scale)

            // Expanded preview
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .elevatedCardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Technique spotlight: \(technique.name)")
    }

    // MARK: - Header

    private var headerContent: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Constants.Colors.accentGold.opacity(0.15), Constants.Colors.accentGold.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: "book.pages")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Constants.Colors.accentGold)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Technique Spotlight")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(Constants.Colors.accentGold)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                Text(technique.name)
                    .font(Constants.Typography.callout)
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .lineLimit(1)

                if let creator = deepDive.creator {
                    Text("by \(creator.name)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.quaternary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .animation(.spring(response: 0.3), value: isExpanded)
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Origin story snippet
            if let story = deepDive.originStory {
                Text(story.prefix(200) + (story.count > 200 ? "..." : ""))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Tasting notes teaser
            if let notes = deepDive.tastingNotes {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Constants.Colors.accentGold)
                        .padding(.top, 2)
                    Text(notes.prefix(120) + (notes.count > 120 ? "..." : ""))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            // Quick tips preview (first 2)
            if !deepDive.tips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(deepDive.tips.prefix(2), id: \.self) { tip in
                        Label {
                            Text(tip)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green.opacity(0.7))
                        }
                    }
                }
            }

            // Video thumbnail (first one only)
            if let video = deepDive.videos.first {
                VideoThumbnailCard(video: video)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // CTA button
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Text("Explore Technique")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous)
                        .fill(Constants.Colors.accentGold)
                )
            }
            .buttonStyle(.scale)
            .accessibilityLabel("Explore \(technique.name)")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}
