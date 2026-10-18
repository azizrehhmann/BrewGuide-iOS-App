import SwiftUI
import CoreData

struct MainTabView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var activeTab: KFloatingTabBar.TabItem = .today

    var body: some View {
        Group {
            switch activeTab {
            case .today:
                tabRoot { HomeView() }
            case .library:
                tabRoot { LibraryView() }
            case .pantry:
                tabRoot { BeanInventoryView(context: managedObjectContext) }
            case .journal:
                tabRoot { BrewJournalView(context: managedObjectContext) }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onOpenURL { url in
            guard url.scheme == "brewguide" else { return }
            if url.host == "brew", url.path == "/resume" {
                appEnvironment.shouldShowActiveBrew = true
            } else if url.host == "suggestion" {
                appEnvironment.shouldShowDailySuggestion = true
                activeTab = .today
            }
        }
    }

    /// The bar is an inset of each tab's root screen, so pushed screens (bean selection, brewing)
    /// get the full height and root lists scroll clear of it.
    private func tabRoot<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack {
            content()
                .safeAreaInset(edge: .bottom) {
                    KFloatingTabBar(activeTab: $activeTab)
                        .padding(.bottom, 8)
                }
        }
    }
}
