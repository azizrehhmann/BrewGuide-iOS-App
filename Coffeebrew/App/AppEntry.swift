import SwiftUI
import CoreData

@main
struct AppEntry: App {
    @StateObject private var appEnvironment = AppEnvironment()
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            if appEnvironment.hasSeenOnboarding {
                HomeView()
                    .environmentObject(appEnvironment)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environment(\.locale, appEnvironment.resolvedLocale)
                    .preferredColorScheme(appEnvironment.colorSchemeOverride)
                    .onOpenURL { url in
                        guard url.scheme == "brewguide" else { return }
                        if url.host == "brew", url.path == "/resume" {
                            appEnvironment.shouldShowActiveBrew = true
                        } else if url.host == "suggestion" {
                            appEnvironment.shouldShowDailySuggestion = true
                        }
                    }
            } else {
                OnboardingView(hasSeenOnboarding: $appEnvironment.hasSeenOnboarding)
                    .environmentObject(appEnvironment)
                    .environment(\.locale, appEnvironment.resolvedLocale)
                    .preferredColorScheme(appEnvironment.colorSchemeOverride)
            }
        }
        .onChange(of: appEnvironment.preferredLanguage) {
            appEnvironment.applyLanguageOnLaunch()
        }
    }
}
