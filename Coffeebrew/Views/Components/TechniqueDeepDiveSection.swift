import SwiftUI

struct TechniqueDeepDiveSection: View {
    let deepDive: TechniqueDeepDive
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Toggle header
            Button {
                withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                HapticsManager.shared.selection()
            } label: {
                HStack {
                    Label("Deep Dive", systemImage: "book.pages")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Constants.Colors.accentGold)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(reduceMotion ? .none : .spring(response: 0.3), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Deep dive, \(isExpanded ? "collapse" : "expand")")
            .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand") technique details")

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 20) {

                    // Origin story
                    if let story = deepDive.originStory {
                        DeepDiveBlock(icon: "map", title: "Origin Story", tint: Constants.Colors.accentGold) {
                            Text(story)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Creator bio
                    if let creator = deepDive.creator {
                        DeepDiveBlock(icon: "person.fill", title: creator.name, tint: Constants.Colors.accentGold) {
                            Text(creator.bio)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let urlString = creator.url, let url = URL(string: urlString) {
                                Link("Learn more", destination: url)
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(Constants.Colors.accentGold)
                            }
                        }
                    }

                    // Tasting notes
                    if let notes = deepDive.tastingNotes {
                        DeepDiveBlock(icon: "cup.and.saucer.fill", title: "What to Expect in the Cup", tint: Constants.Colors.accentGold) {
                            Text(notes)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Common mistakes
                    if !deepDive.commonMistakes.isEmpty {
                        DeepDiveBlock(icon: "exclamationmark.triangle", title: "Common Mistakes", tint: .orange) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(deepDive.commonMistakes, id: \.self) { mistake in
                                    Label {
                                        Text(mistake)
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    } icon: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.red.opacity(0.7))
                                    }
                                }
                            }
                        }
                    }

                    // Tips
                    if !deepDive.tips.isEmpty {
                        DeepDiveBlock(icon: "lightbulb.fill", title: "Tips", tint: .teal) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(deepDive.tips, id: \.self) { tip in
                                    Label {
                                        Text(tip)
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    } icon: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.green.opacity(0.7))
                                    }
                                }
                            }
                        }
                    }

                    // Videos
                    if !deepDive.videos.isEmpty {
                        DeepDiveBlock(icon: "play.rectangle.fill", title: "Watch", tint: .red) {
                            VStack(spacing: 10) {
                                ForEach(deepDive.videos) { video in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(video.title)
                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        VideoThumbnailCard(video: video)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .move(edge: .top))
                )
            }
        }
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
    }
}

// MARK: - Reusable Content Block

private struct DeepDiveBlock<Content: View>: View {
    let icon: String
    let title: String
    let tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(tint)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }
}
