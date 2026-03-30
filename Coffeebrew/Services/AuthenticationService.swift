import AuthenticationServices
import SwiftUI
import CryptoKit
import Combine

/// Manages user authentication via Sign in with Apple.
/// Profile data is stored in Keychain for persistence across app launches.
@MainActor
final class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()

    @Published var isSignedIn: Bool = false
    @Published var userProfile: UserProfile?
    @Published var syncStatus: SyncStatus = .idle

    // MARK: - Types

    struct UserProfile: Codable, Equatable {
        let userId: String
        let fullName: String?
        let email: String?
        let signInProvider: SignInProvider

        var displayName: String {
            fullName ?? email ?? "Coffee Lover"
        }

        var initials: String {
            guard let name = fullName, !name.isEmpty else { return "CL" }
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }
    }

    enum SignInProvider: String, Codable {
        case apple
        case google
    }

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced
        case error(String)

        var label: String {
            switch self {
            case .idle: return "Not syncing"
            case .syncing: return "Syncing..."
            case .synced: return "Up to date"
            case .error(let msg): return msg
            }
        }

        var icon: String {
            switch self {
            case .idle: return "icloud.slash"
            case .syncing: return "arrow.triangle.2.circlepath.icloud"
            case .synced: return "checkmark.icloud"
            case .error: return "exclamationmark.icloud"
            }
        }

        var color: Color {
            switch self {
            case .idle: return .secondary
            case .syncing: return .blue
            case .synced: return .green
            case .error: return .orange
            }
        }
    }

    // MARK: - Keychain Keys

    private let keychainServiceKey = "com.brewguide.auth"
    private let profileKey = "userProfile"

    // MARK: - Init

    private init() {
        loadStoredProfile()
        observeCloudKitSync()
    }

    // MARK: - Sign in with Apple

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }

            let userId = appleCredential.user

            // Apple only provides name/email on FIRST sign-in
            var fullName: String?
            if let nameComponents = appleCredential.fullName {
                let formatter = PersonNameComponentsFormatter()
                let formatted = formatter.string(from: nameComponents)
                if !formatted.trimmingCharacters(in: .whitespaces).isEmpty {
                    fullName = formatted
                }
            }

            let email = appleCredential.email

            // Merge with existing profile (Apple only sends name/email once)
            let existing = userProfile
            let profile = UserProfile(
                userId: userId,
                fullName: fullName ?? existing?.fullName,
                email: email ?? existing?.email,
                signInProvider: .apple
            )

            userProfile = profile
            isSignedIn = true
            saveProfile(profile)

        case .failure:
            break
        }
    }

    /// Check if the Apple ID credential is still valid
    func checkAppleCredentialState() {
        guard let profile = userProfile, profile.signInProvider == .apple else { return }

        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: profile.userId) { state, _ in
            Task { @MainActor [weak self] in
                switch state {
                case .authorized:
                    self?.isSignedIn = true
                case .revoked, .notFound:
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Google Sign In (OAuth via ASWebAuthenticationSession)

    /// Initiates Google OAuth flow using ASWebAuthenticationSession.
    /// Note: Requires a valid Google OAuth Client ID configured in the app.
    /// Set up at https://console.cloud.google.com/apis/credentials
    func initiateGoogleSignIn(presentationAnchor: ASPresentationAnchor) {
        // Placeholder: Replace with your Google OAuth Client ID
        let clientId = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
        let redirectURI = "com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID:/oauthredirect"

        guard clientId != "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com" else {
            // Google Sign-In not configured yet
            return
        }

        let nonce = UUID().uuidString
        let scope = "openid%20email%20profile"

        let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
            + "?client_id=\(clientId)"
            + "&redirect_uri=\(redirectURI)"
            + "&response_type=code"
            + "&scope=\(scope)"
            + "&nonce=\(nonce)"

        guard let url = URL(string: authURL) else { return }

        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: redirectURI.components(separatedBy: ":").first) { [weak self] callbackURL, error in
            guard error == nil, let callbackURL else { return }

            // Parse the authorization code from callback
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let _ = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                return
            }

            // In a full implementation, exchange the code for tokens via your backend
            // For now, create a basic profile
            let profile = UserProfile(
                userId: "google_\(nonce)",
                fullName: nil,
                email: nil,
                signInProvider: .google
            )

            Task { @MainActor [weak self] in
                self?.userProfile = profile
                self?.isSignedIn = true
                self?.saveProfile(profile)
            }
        }

        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    // MARK: - Sign Out

    func signOut() {
        isSignedIn = false
        userProfile = nil
        deleteStoredProfile()
    }

    // MARK: - CloudKit Sync Observation

    private func observeCloudKitSync() {
        // Sync status is updated by PersistenceController via updateSyncStatusFromBackground()
        // No duplicate observer needed here — PersistenceController already listens
        // for .NSPersistentStoreRemoteChange on the correct store coordinator
    }

    func updateSyncStatus(_ status: SyncStatus) {
        syncStatus = status
    }

    nonisolated func updateSyncStatusFromBackground(_ status: SyncStatus) {
        Task { @MainActor in
            self.syncStatus = status
        }
    }

    // MARK: - Keychain Persistence

    private func saveProfile(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceKey,
            kSecAttrAccount as String: profileKey
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadStoredProfile() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceKey,
            kSecAttrAccount as String: profileKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data,
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return
        }

        userProfile = profile
        isSignedIn = true
    }

    private func deleteStoredProfile() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceKey,
            kSecAttrAccount as String: profileKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}
