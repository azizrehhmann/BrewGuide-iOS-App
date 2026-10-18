import SwiftUI
import CoreData

struct MainTabView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var activeTab: KFloatingTabBar.TabItem = .today

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch activeTab {
                case .today:
                    NavigationStack {
                        HomeView()
                    }
                case .library:
                    NavigationStack {
                        LibraryView()
                    }
                case .pantry:
                    NavigationStack {
                        BeanInventoryView(context: managedObjectContext)
                    }
                case .journal:
                    NavigationStack {
                        BrewJournalView(context: managedObjectContext)
                    }
                }
            }

            KFloatingTabBar(activeTab: $activeTab)
                .padding(.bottom, 8)
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
}
