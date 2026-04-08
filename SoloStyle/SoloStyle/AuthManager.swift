//
//  AuthManager.swift
//  SoloStyle
//
//  Telegram + Apple authentication manager with Keychain JWT storage
//

import AuthenticationServices
import Foundation
import Security
import SwiftUI

// MARK: - User Data

nonisolated struct TelegramUser: Codable, Sendable {
    let telegramId: Int64?
    let firstName: String
    let lastName: String?
    let username: String?
    let photoUrl: String?
    let email: String?
    let appleUserId: String?

    enum CodingKeys: String, CodingKey {
        case telegramId = "telegram_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case photoUrl = "photo_url"
        case email
        case appleUserId = "apple_user_id"
    }
}

// MARK: - Apple Sign-In Delegate

/// Bridges ASAuthorizationController delegate callbacks to async/await via a continuation.
/// Must only be used once per instance — create a new delegate for each sign-in attempt.
@MainActor
private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    func signIn() async throws -> ASAuthorizationAppleIDCredential {
        guard continuation == nil else {
            throw AuthError.invalidCredential // Already in use
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                continuation?.resume(throwing: AuthError.invalidCredential)
                continuation = nil
                return
            }
            continuation?.resume(returning: credential)
            continuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

private enum AuthError: Error, LocalizedError {
    case invalidCredential
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Invalid Apple credential"
        case .missingIdentityToken: return "Missing identity token from Apple"
        }
    }
}

// MARK: - Auth Manager

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    // MARK: - State

    var isAuthenticated = false
    var isAuthenticating = false
    var authError: String?
    var currentUser: TelegramUser?
    var selectedRole: UserRole?

    // Pending auth token for Telegram flow
    private var pendingAuthToken: String?
    private var pollTask: Task<Void, Never>?
    private var pollAttempts = 0

    // Prevent delegate from being deallocated during Apple Sign-In flow
    private var appleSignInDelegate: AppleSignInDelegate?

    private init() {
        // Check Keychain for existing JWT on launch
        if let jwt = loadJWT() {
            // Decode JWT payload and check expiry before trusting it
            if isJWTExpired(jwt) {
                print("[AUTH] JWT expired at startup, clearing")
                deleteJWT()
            } else {
                isAuthenticated = true
                Task { await NetworkManager.shared.setJWT(jwt) }
                // Load cached role
                if let roleStr = UserDefaults.standard.string(forKey: "userRole"),
                   let role = UserRole(rawValue: roleStr) {
                    selectedRole = role
                }
                // Load cached user data
                if let data = UserDefaults.standard.data(forKey: "cachedUser"),
                   let user = try? JSONDecoder().decode(TelegramUser.self, from: data) {
                    currentUser = user
                }
            }
        }
    }

    // MARK: - Telegram Auth Flow

    /// Step 1: Generate auth token, register with backend, open Telegram deep link
    func startTelegramAuth() async {
        isAuthenticating = true
        authError = nil

        let authToken = UUID().uuidString
        pendingAuthToken = authToken

        do {
            // Register token with backend
            try await NetworkManager.shared.registerAuthToken(authToken)

            // Open Telegram deep link
            let botUsername = "solostyle_registration_bot"
            if let deepLink = URL(string: "tg://resolve?domain=\(botUsername)&start=\(authToken)") {
                await UIApplication.shared.open(deepLink)
            }

            // Start polling backend for auth completion
            startPolling(authToken: authToken)

        } catch {
            authError = L.authError
            isAuthenticating = false
        }
    }

    // MARK: - Apple Sign-In Flow

    /// Present Apple Sign-In sheet, get credential, authenticate with backend, complete auth
    func startAppleSignIn() async {
        isAuthenticating = true
        authError = nil

        do {
            let delegate = AppleSignInDelegate()
            appleSignInDelegate = delegate // retain during flow

            let credential = try await delegate.signIn()

            guard let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                throw AuthError.missingIdentityToken
            }

            let firstName = credential.fullName?.givenName
            let lastName = credential.fullName?.familyName
            let email = credential.email

            // Send to backend
            let jwt = try await NetworkManager.shared.appleAuth(
                identityToken: identityToken,
                userId: credential.user,
                firstName: firstName,
                lastName: lastName,
                email: email
            )

            await completeAuth(jwt: jwt)

        } catch let error as ASAuthorizationError where error.code == .canceled {
            // User cancelled — not an error
            isAuthenticating = false
        } catch let error as AuthError {
            print("[AUTH] Apple Sign-In error: \(error)")
            authError = L.authError
            isAuthenticating = false
        } catch {
            print("[AUTH] Apple Sign-In unexpected error: \(error)")
            authError = L.authError
            isAuthenticating = false
        }

        appleSignInDelegate = nil
    }

    /// Handle Apple Sign-In result from SignInWithAppleButton
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8)
            else {
                authError = L.authError
                return
            }

            isAuthenticating = true
            authError = nil

            do {
                let jwt = try await NetworkManager.shared.appleAuth(
                    identityToken: identityToken,
                    userId: credential.user,
                    firstName: credential.fullName?.givenName,
                    lastName: credential.fullName?.familyName,
                    email: credential.email
                )
                await completeAuth(jwt: jwt)
            } catch {
                authError = L.authError
                isAuthenticating = false
            }

        case .failure:
            authError = L.authError
        }
    }

    /// Handle callback URL (solostyle://auth?token=JWT)
    func handleAuthCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "solostyle",
              components.host == "auth",
              let jwt = components.queryItems?.first(where: { $0.name == "token" })?.value,
              jwt.components(separatedBy: ".").count == 3
        else { return }

        stopPolling()
        await completeAuth(jwt: jwt)
    }

    /// Select role after auth
    func selectRole(_ role: UserRole) async {
        selectedRole = role
        UserDefaults.standard.set(role.rawValue, forKey: "userRole")

        // Notify backend
        if let jwt = loadJWT() {
            do {
                try await NetworkManager.shared.updateUserRole(role, jwt: jwt)
            } catch {
                print("[AUTH] Failed to update role on backend: \(error)")
                // Role saved locally, will sync on next launch
            }
        }
    }

    /// Logout
    func logout() {
        deleteJWT()
        isAuthenticated = false
        isAuthenticating = false
        currentUser = nil
        selectedRole = nil
        pendingAuthToken = nil
        stopPolling()
        UserDefaults.standard.removeObject(forKey: "userRole")
        UserDefaults.standard.removeObject(forKey: "cachedUser")
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    // MARK: - Polling

    /// Poll backend to check if Telegram auth completed
    private func startPolling(authToken: String) {
        stopPolling()
        pollAttempts = 0
        let maxAttempts = 60

        pollTask = Task { [weak self] in
            var consecutiveErrors = 0
            while !Task.isCancelled {
                // Exponential backoff: 5s base, doubles on consecutive errors (max 30s)
                let backoff = min(5_000_000_000 * UInt64(1 << min(consecutiveErrors, 3)), 30_000_000_000)
                try? await Task.sleep(nanoseconds: backoff)
                guard !Task.isCancelled, let self else { return }

                self.pollAttempts += 1
                if self.pollAttempts >= maxAttempts {
                    self.stopPolling()
                    self.authError = L.authError
                    self.isAuthenticating = false
                    return
                }

                let success = await self.checkAuthStatus(authToken: authToken)
                consecutiveErrors = success ? 0 : consecutiveErrors + 1
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Returns true if the request succeeded (even if auth not yet complete), false on network error
    private func checkAuthStatus(authToken: String) async -> Bool {
        do {
            let result = try await NetworkManager.shared.checkAuthToken(authToken)
            if let jwt = result {
                stopPolling()
                await completeAuth(jwt: jwt)
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Auth Completion

    private func completeAuth(jwt: String) async {
        do {
            let result = try await NetworkManager.shared.validateToken(jwt)
            saveJWT(jwt)
            currentUser = result.user
            isAuthenticated = true
            isAuthenticating = false

            // Restore role from backend if available
            if let roleStr = result.role, let role = UserRole(rawValue: roleStr) {
                selectedRole = role
                UserDefaults.standard.set(role.rawValue, forKey: "userRole")
            }

            // Cache user data for quick loading
            if let data = try? JSONEncoder().encode(result.user) {
                UserDefaults.standard.set(data, forKey: "cachedUser")
            }
        } catch {
            authError = L.authError
            isAuthenticating = false
        }
    }

    // MARK: - JWT Helpers

    /// Decode JWT payload (base64 middle segment) and check if `exp` claim is in the past.
    private func isJWTExpired(_ jwt: String) -> Bool {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return true }

        var base64 = String(parts[1])
        // Pad to multiple of 4 for base64 decoding
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let payloadData = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true // Can't decode — treat as expired
        }

        return Date().timeIntervalSince1970 >= exp
    }

    // MARK: - Keychain Helpers

    private let keychainService = "com.solostyle.SoloStyle"
    private let keychainAccount = "jwt_token"

    func loadJWT() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveJWT(_ token: String) {
        deleteJWT() // Remove old token first

        guard let data = token.data(using: .utf8) else {
            print("[AUTH] Keychain save failed: cannot encode token to UTF-8")
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[AUTH] Keychain save failed: OSStatus \(status)")
            // Retry after explicit delete (clean query without value/accessible)
            deleteJWT()
            let retryStatus = SecItemAdd(query as CFDictionary, nil)
            if retryStatus != errSecSuccess {
                print("[AUTH] Keychain save retry also failed: OSStatus \(retryStatus)")
            }
        }
    }

    private func deleteJWT() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("[AUTH] Keychain delete failed: OSStatus \(status)")
        }
    }
}
