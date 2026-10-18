import SwiftUI
import CoreData

@main
struct AppEntry: App {
    @StateObject private var appEnvironment = AppEnvironment()
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            if appEnvironment.hasSeenOnboarding {
                MainTabView()
                    .environmentObject(appEnvironment)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environment(\.locale, appEnvironment.resolvedLocale)
                    .preferredColorScheme(appEnvironment.colorSchemeOverride)
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
