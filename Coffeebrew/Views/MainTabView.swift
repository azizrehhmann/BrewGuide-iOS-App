import SwiftUI
import CoreData

struct MainTabView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var activeTab: KFloatingTabBar.TabItem = .today
    @State private var paths: [KFloatingTabBar.TabItem: NavigationPath] = [:]

    var body: some View {
        // All tabs stay alive, so switching keeps scroll, search and any screen pushed in a tab
        TabView(selection: $activeTab) {
            tabRoot(.today) { HomeView(navigationPath: path(.today)) }
            tabRoot(.library) { LibraryView() }
            tabRoot(.pantry) { BeanInventoryView(context: managedObjectContext) }
            tabRoot(.journal) { BrewJournalView(context: managedObjectContext) }
        }
        .ignoresSafeArea(.keyboard)
        // Brew screens end a brew with appEnvironment.reset(); pop the tab it was started from
        .onReceive(appEnvironment.$selectedMethod) { method in
            if method == nil { paths[activeTab] = NavigationPath() }
        }
        .onOpenURL { url in
            guard url.scheme == "brewguide" else { return }
            if url.host == "suggestion" { activeTab = .today }
        }
    }

    private func path(_ tab: KFloatingTabBar.TabItem) -> Binding<NavigationPath> {
        Binding(get: { paths[tab] ?? NavigationPath() }, set: { paths[tab] = $0 })
    }

    /// The bar is an inset of each tab's root screen, so pushed screens (bean selection, brewing)
    /// get the full height and root lists scroll clear of it.
    private func tabRoot<Content: View>(_ tab: KFloatingTabBar.TabItem, @ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack(path: path(tab)) {
            content()
                .safeAreaInset(edge: .bottom) {
                    KFloatingTabBar(activeTab: $activeTab)
                        .padding(.bottom, 8)
                }
        }
        .toolbar(.hidden, for: .tabBar)  // the floating bar replaces the system one on every screen of the tab
        .tag(tab)
    }
}
