import SwiftUI

/// Horizontal scrolling sections for Favourites and Recents on the HomeView.
struct FavouritesRecentsSection: View {
    @ObservedObject var viewModel: FavouritesRecentsViewModel
    let onSelectTechnique: (Technique) -> Void
    let onQuickRebrew: (FavouritesRecentsViewModel.TechniqueQuickBrew) -> Void

    var body: some View {
        VStack(spacing: 24) {
            if !viewModel.favouriteTechniques.isEmpty {
                techniqueRow(
                    title: "Favourites",
                    icon: "heart.fill",
                    items: viewModel.favouriteTechniques
                )
            }

            if !viewModel.recentTechniques.isEmpty {
                techniqueRow(
                    title: "Recently Brewed",
                    icon: "clock.arrow.circlepath",
                    items: viewModel.recentTechniques
                )
            }
        }
    }

    // MARK: - Section Row

    private func techniqueRow(
        title: String,
        icon: String,
        items: [FavouritesRecentsViewModel.TechniqueQuickBrew]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Constants.Colors.accentGold)
                Text(title)
                    .font(Constants.Typography.callout)
                    .foregroundStyle(Constants.Colors.primaryColor)
            }
            .padding(.horizontal, Constants.Layout.horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        QuickBrewCard(
                            item: item,
                            onTap: { onSelectTechnique(item.technique) },
                            onQuickBrew: { onQuickRebrew(item) },
                            onToggleFavourite: { viewModel.toggleFavourite(techniqueId: item.id) }
                        )
                    }
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
            }
        }
    }
}

// MARK: - Quick Brew Card

struct QuickBrewCard: View {
    let item: FavouritesRecentsViewModel.TechniqueQuickBrew
    let onTap: () -> Void
    let onQuickBrew: () -> Void
    let onToggleFavourite: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top: icon + favourite
            HStack(alignment: .top) {
                Image(item.technique.imageName)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)

                Spacer()

                Button {
                    withAnimation(Constants.Animation.spring) {
                        onToggleFavourite()
                    }
                    HapticsManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: item.isFavourite ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(item.isFavourite ? Constants.Colors.accentGold : Color.secondary.opacity(0.4))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isFavourite ? "Remove from favourites" : "Add to favourites")
            }

            // Name + method
            VStack(alignment: .leading, spacing: 2) {
                Text(item.technique.name)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Constants.Colors.primaryColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(item.method.name)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Brew count + time ago
            HStack(spacing: 4) {
                Text("\(item.brewCount)\u{00D7}")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(Constants.Colors.accentGold)

                Text(relativeTime(item.lastBrewedAt))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            // Quick re-brew button
            Button(action: onQuickBrew) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .bold))
                    Text("Re-brew")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Constants.Colors.accentGold)
                )
            }
            .buttonStyle(.scale)
            .accessibilityLabel("Quick re-brew \(item.technique.name)")
        }
        .padding(14)
        .frame(width: 155)
        .frame(minHeight: 180)
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
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("View Technique", systemImage: "info.circle")
            }

            Button {
                onQuickBrew()
            } label: {
                Label("Quick Re-brew", systemImage: "arrow.counterclockwise")
            }

            Divider()

            Button {
                onToggleFavourite()
            } label: {
                Label(
                    item.isFavourite ? "Remove from Favourites" : "Add to Favourites",
                    systemImage: item.isFavourite ? "heart.slash" : "heart"
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.technique.name), \(item.method.name), brewed \(item.brewCount) times")
    }

    // MARK: - Helpers

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 {
            return "just now"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let weeks = Int(interval / 604800)
            return "\(weeks)w ago"
        }
    }
}
