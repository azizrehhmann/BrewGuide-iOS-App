import SwiftUI

struct KFloatingTabBar: View {
    @Binding var activeTab: TabItem
    @Environment(\.colorScheme) private var colorScheme

    enum TabItem: String, CaseIterable {
        case today = "Today"
        case library = "Library"
        case pantry = "Pantry"
        case journal = "Journal"

        var icon: String {
            switch self {
            case .today: return "cup.and.saucer.fill"
            case .library: return "book.fill"
            case .pantry: return "leaf.fill"
            case .journal: return "bookmark.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeTab = tab
                    }
                    HapticsManager.shared.selection()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 19, weight: activeTab == tab ? .semibold : .regular))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: activeTab == tab ? .semibold : .medium))
                            .tracking(0.2)
                    }
                    .foregroundStyle(activeTab == tab ? Constants.Colors.accentGold : Constants.Colors.primaryColor.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        activeTab == tab
                            ? Constants.Colors.accentGold.opacity(0.08)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 22)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.black.opacity(0.06),
                    lineWidth: 0.5
                )
        )
        .padding(.horizontal, 16)
    }
}
