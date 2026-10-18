import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @ObservedObject private var authService = AuthenticationService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if authService.isSignedIn, let profile = authService.userProfile {
                        signedInContent(profile: profile)
                    } else {
                        signedOutContent
                    }

                    syncStatusSection
                    cloudInfoSection
                }
                .padding(.vertical, 16)
            }
            .adaptiveBackground()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Sign Out?", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your data will remain on this device but will no longer sync to iCloud.")
            }
            .onAppear {
                authService.checkAppleCredentialState()
            }
        }
    }

    // MARK: - Signed In

    private func signedInContent(profile: AuthenticationService.UserProfile) -> some View {
        VStack(spacing: 20) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Constants.Colors.accentGold, Constants.Colors.accentGold.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Text(profile.initials)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(profile.displayName)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Constants.Colors.primaryColor)

                if let email = profile.email {
                    Text(email)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: profile.signInProvider == .apple ? "apple.logo" : "globe")
                        .font(.system(size: 10))
                    Text("Signed in with Apple")
                        .font(.system(.caption2, design: .rounded))
                }
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
            }

            Button(role: .destructive) {
                showSignOutConfirm = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13))
                    Text("Sign Out")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Color.red.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    // MARK: - Signed Out

    private var signedOutContent: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Constants.Colors.accentGold)

                Text("Sign In")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Constants.Colors.primaryColor)

                Text("Sign in to sync your brew journal, bean inventory, and favourites across all your Apple devices.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 12)

            // Sign in with Apple button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                authService.handleAppleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius, style: .continuous))
            .padding(.horizontal, Constants.Layout.horizontalPadding)

            // Skip note
            Text("You can also use the app without signing in.\nYour data will stay on this device only.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Sync Status

    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "icloud")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Constants.Colors.accentGold)
                Text("iCloud Sync")
                    .font(Constants.Typography.callout)
                    .foregroundStyle(Constants.Colors.primaryColor)
            }

            VStack(spacing: 0) {
                syncRow(
                    icon: authService.syncStatus.icon,
                    title: "Sync Status",
                    value: authService.syncStatus.label,
                    valueColor: authService.syncStatus.color
                )

                Divider().padding(.horizontal, 16)

                syncRow(
                    icon: "book.closed.fill",
                    title: "Brew Journal",
                    value: "Syncs automatically",
                    valueColor: .secondary
                )

                Divider().padding(.horizontal, 16)

                syncRow(
                    icon: "leaf.fill",
                    title: "Bean Inventory",
                    value: "Syncs automatically",
                    valueColor: .secondary
                )

                Divider().padding(.horizontal, 16)

                syncRow(
                    icon: "heart.fill",
                    title: "Favourites",
                    value: "Syncs automatically",
                    valueColor: .secondary
                )
            }
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                    .fill(Constants.Colors.cardBackground)
            )
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }

    private func syncRow(icon: String, title: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Cloud Info

    private var cloudInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11))
                Text("Your data is encrypted and stored in your personal iCloud account. Only you can access it.")
                    .font(.system(.caption2, design: .rounded))
            }
            .foregroundStyle(.tertiary)

            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                Text("Changes sync automatically when connected to the internet.")
                    .font(.system(.caption2, design: .rounded))
            }
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Constants.Layout.horizontalPadding)
    }
}
