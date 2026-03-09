//
//  AuthManager.swift
//  SoloStyle
//
//  Telegram authentication manager with Keychain JWT storage
//

import Foundation
import Security
import SwiftUI

// MARK: - Telegram User Data

nonisolated struct TelegramUser: Codable, Sendable {
    let telegramId: Int64
    let firstName: String
    let lastName: String?
    let username: String?
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case telegramId = "telegram_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case photoUrl = "photo_url"
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
    private var pollTimer: Timer?

    private init() {
        // Check Keychain for existing JWT on launch
        if let jwt = loadJWT() {
            isAuthenticated = true
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
            _ = jwt // JWT loaded, will be used for API calls
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

    /// Step 2: Handle callback URL (solostyle://auth?token=JWT)
    func handleAuthCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "solostyle",
              components.host == "auth",
              let jwt = components.queryItems?.first(where: { $0.name == "token" })?.value
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
            try? await NetworkManager.shared.updateUserRole(role, jwt: jwt)
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
        var attempts = 0
        let maxAttempts = 60 // 5 minutes at 5-second intervals

        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                attempts += 1
                if attempts >= maxAttempts {
                    self?.stopPolling()
                    self?.authError = L.authError
                    self?.isAuthenticating = false
                    return
                }

                Task {
                    await self?.checkAuthStatus(authToken: authToken)
                }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkAuthStatus(authToken: String) async {
        do {
            let result = try await NetworkManager.shared.checkAuthToken(authToken)
            if let jwt = result {
                stopPolling()
                await completeAuth(jwt: jwt)
            }
        } catch {
            // Keep polling, don't show error yet
        }
    }

    // MARK: - Auth Completion

    private func completeAuth(jwt: String) async {
        do {
            let user = try await NetworkManager.shared.validateToken(jwt)
            saveJWT(jwt)
            currentUser = user
            isAuthenticated = true
            isAuthenticating = false

            // Cache user data for quick loading
            if let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: "cachedUser")
            }
        } catch {
            authError = L.authError
            isAuthenticating = false
        }
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

        guard let data = token.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteJWT() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
