import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @ObservedObject private var authService = AuthenticationService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            List {
                accountSection
                appearanceSection
                languageSection
                unitsSection
                brewingDefaultsSection
                liveActivitySection
                dailySuggestionSection
                accessibilitySection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section {
            Button {
                showProfile = true
            } label: {
                HStack(spacing: 14) {
                    if authService.isSignedIn, let profile = authService.userProfile {
                        // Signed in avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Constants.Colors.accentGold, Constants.Colors.accentGold.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            Text(profile.initials)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.displayName)
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundStyle(.primary)
                            HStack(spacing: 4) {
                                Image(systemName: authService.syncStatus.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(authService.syncStatus.color)
                                Text(authService.syncStatus.label)
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        // Signed out
                        ZStack {
                            Circle()
                                .fill(Constants.Colors.primaryColor.opacity(0.08))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sign In")
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundStyle(.primary)
                            Text("Sync data across devices")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.quaternary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("Account")
        } footer: {
            if authService.isSignedIn {
                Text("Your brew journal, bean inventory, and favourites sync across all your devices via iCloud.")
            } else {
                Text("Sign in to sync your data across all your Apple devices.")
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $appEnvironment.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.navigationLink)
            .accessibilityLabel("Appearance mode")
        } header: {
            Text("Appearance")
        } footer: {
            Text("Choose System to follow your device's Dark Mode setting.")
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        Section {
            Picker(selection: $appEnvironment.preferredLanguage) {
                Label("System Default", systemImage: "globe")
                    .tag("system")
                Label("English", systemImage: "character.textbox")
                    .tag("en")
                Label("日本語", systemImage: "character.textbox")
                    .tag("ja")
                Label("Deutsch", systemImage: "character.textbox")
                    .tag("de")
                Label("Français", systemImage: "character.textbox")
                    .tag("fr")
            } label: {
                Label("Language", systemImage: "globe")
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Language")
        } footer: {
            Text("Changes the app language immediately. Brew steps and methods will also update.")
        }
    }

    // MARK: - Units

    private var unitsSection: some View {
        Section {
            Toggle(isOn: $appEnvironment.useFahrenheit) {
                Label("Temperature in °F", systemImage: "thermometer.medium")
            }
            .tint(Constants.Colors.accentGold)

            Toggle(isOn: $appEnvironment.useFluidOunces) {
                Label("Water Volume in fl oz", systemImage: "drop.fill")
            }
            .tint(Constants.Colors.accentGold)
        } header: {
            Text("Units")
        } footer: {
            Text("Toggle between metric (°C / ml) and imperial (°F / fl oz) units.")
        }
    }

    // MARK: - Brewing Defaults

    private var brewingDefaultsSection: some View {
        Section {
            Stepper(value: $appEnvironment.defaultServings, in: 1...6) {
                Label("Default Servings: \(appEnvironment.defaultServings)", systemImage: "cup.and.saucer.fill")
            }
            .accessibilityLabel("Default serving size, \(appEnvironment.defaultServings) cups")

            Toggle(isOn: $appEnvironment.autoAdvanceEnabled) {
                Label("Auto-Advance Steps", systemImage: "forward.fill")
            }
            .tint(Constants.Colors.accentGold)
        } header: {
            Text("Brewing Defaults")
        } footer: {
            Text("These defaults apply when starting a new brew session. You can override them per-session.")
        }
    }

    // MARK: - Live Activity

    private var liveActivitySection: some View {
        Section {
            Toggle(isOn: $appEnvironment.liveActivityEnabled) {
                Label("Show Brew Timer on Lock Screen", systemImage: "timer")
            }
            .tint(Constants.Colors.accentGold)
        } header: {
            Text("Live Activity")
        } footer: {
            Text("Shows your brew step timer on the Lock Screen and Dynamic Island while brewing.")
        }
    }

    // MARK: - Daily Suggestion

    private var dailySuggestionSection: some View {
        Section {
            Toggle(isOn: $appEnvironment.dailySuggestionNotification) {
                Label("Daily Brew Notification", systemImage: "bell.badge.fill")
            }
            .tint(Constants.Colors.accentGold)
        } header: {
            Text("Daily Suggestion")
        } footer: {
            Text("Get a daily notification at 8am with a personalised brewing suggestion.")
        }
    }

    // MARK: - Accessibility

    private var accessibilitySection: some View {
        Section {
            Toggle(isOn: $appEnvironment.hapticsEnabled) {
                Label("Haptic Feedback", systemImage: "hand.tap.fill")
            }
            .tint(Constants.Colors.accentGold)

            Button {
                appEnvironment.hasSeenOnboarding = false
                dismiss()
            } label: {
                Label("Replay Onboarding", systemImage: "arrow.counterclockwise")
            }
            .accessibilityLabel("Show the onboarding walkthrough again")
        } header: {
            Text("Accessibility")
        } footer: {
            Text("Haptic feedback plays during step transitions and timer events.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("Methods", value: "\(appEnvironment.databaseService.methods.count)")
            LabeledContent("Techniques", value: "\(appEnvironment.databaseService.techniques.count)")
        }
    }
}
