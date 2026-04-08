//
//  NetworkManager.swift
//  SoloStyle
//
//  Network layer for SoloStyle API (async/await)
//

import Foundation

// MARK: - API Models

nonisolated struct SearchRequest: Codable, Sendable {
    let query: String
    let latitude: Double
    let longitude: Double
    let radiusKm: Double

    enum CodingKeys: String, CodingKey {
        case query, latitude, longitude
        case radiusKm = "radius_km"
    }
}

nonisolated struct SearchResponse: Codable, Sendable {
    let answer: String
    let masters: [MasterResult]
}

nonisolated struct MasterResult: Codable, Sendable, Identifiable {
    let serviceId: String
    let serviceName: String
    let serviceDescription: String
    let price: Double
    let similarity: Double
    let masterId: String
    let masterName: String
    let experience: Int
    let rating: Double
    let distanceKm: Double
    let masterLat: Double?
    let masterLon: Double?

    var id: String { serviceId }

    var formattedPrice: String {
        String(format: "%.0f₽", price)
    }

    var formattedDistance: String {
        String(format: "%.1f км", distanceKm)
    }

    enum CodingKeys: String, CodingKey {
        case serviceId = "service_id"
        case serviceName = "service_name"
        case serviceDescription = "service_description"
        case price, similarity
        case masterId = "master_id"
        case masterName = "master_name"
        case experience, rating
        case distanceKm = "distance_km"
        case masterLat = "master_lat"
        case masterLon = "master_lon"
    }
}

// MARK: - Voice CRM Models

nonisolated struct VoiceCRMRequest: Codable, Sendable {
    let text: String
    let timezone: String
}

nonisolated struct VoiceCRMResponse: Codable, Sendable {
    let success: Bool
    let entities: ParsedEntity
    let summary: String
}

nonisolated struct ParsedEntity: Codable, Sendable {
    let clientName: String?
    let phone: String?
    let serviceName: String?
    let date: String?
    let time: String?
    let price: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
        case phone
        case serviceName = "service_name"
        case date, time, price, notes
    }
}

// MARK: - Auth API Models

nonisolated struct AuthTokenRequest: Codable, Sendable {
    let authToken: String
    enum CodingKeys: String, CodingKey {
        case authToken = "auth_token"
    }
}

nonisolated struct AuthTokenCheckResponse: Codable, Sendable {
    let completed: Bool
    let jwt: String?
}

nonisolated struct AuthValidateResponse: Codable, Sendable {
    let user: TelegramUser
    let role: String?
}

nonisolated struct RoleUpdateRequest: Codable, Sendable {
    let role: String
}

nonisolated struct AppleAuthRequest: Codable, Sendable {
    let identityToken: String
    let userId: String
    let firstName: String?
    let lastName: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case email
    }
}

nonisolated struct AppleAuthResponse: Codable, Sendable {
    let ok: Bool
    let jwt: String?
}

nonisolated struct ValidateResult: Sendable {
    let user: TelegramUser
    let role: String?
}

// MARK: - Network Errors

nonisolated enum NetworkError: LocalizedError, Sendable {
    case invalidURL
    case noConnection
    case serverError(Int)
    case decodingError
    case timeout
    case tokenExpired
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Неверный адрес сервера"
        case .noConnection:
            "Нет подключения к серверу. Проверьте, запущен ли бэкенд."
        case .serverError(let code):
            "Ошибка сервера: \(code)"
        case .decodingError:
            "Ошибка обработки ответа"
        case .tokenExpired:
            "Сессия истекла. Войдите заново."
        case .timeout:
            "Сервер не отвечает. Попробуйте позже."
        case .unknown(let msg):
            msg
        }
    }
}

// MARK: - NetworkManager

actor NetworkManager {
    static let shared = NetworkManager()

    // Local dev: "http://localhost:8000/api/v1"
    // Production (Render):
    private let baseURL = "https://solostyle-api.onrender.com/api/v1"

    private let session: URLSession
    private let decoder: JSONDecoder
    private var jwtToken: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    /// Set JWT token for authenticated requests
    func setJWT(_ token: String?) {
        jwtToken = token
    }

    /// Check if current JWT is expired (base64 decode middle segment, check `exp`)
    var isJWTExpired: Bool {
        guard let jwt = jwtToken else { return true }
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return true }
        var base64 = String(parts[1])
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else { return true }
        return Date().timeIntervalSince1970 >= exp
    }

    private func authenticatedRequest(for url: URL) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let jwt = jwtToken {
            if isJWTExpired {
                throw NetworkError.tokenExpired
            }
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: - Auth API

    /// Register a temporary auth token for Telegram login flow
    func registerAuthToken(_ token: String) async throws {
        guard let url = URL(string: baseURL + "/auth/register-token") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(AuthTokenRequest(authToken: token))

        let (_, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }

    /// Check if auth token has been completed (polling)
    func checkAuthToken(_ token: String) async throws -> String? {
        guard let url = URL(string: baseURL + "/auth/check-token") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(AuthTokenRequest(authToken: token))

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        let result = try decoder.decode(AuthTokenCheckResponse.self, from: data)
        return result.completed ? result.jwt : nil
    }

    /// Validate JWT and get user info + role
    func validateToken(_ jwt: String) async throws -> ValidateResult {
        guard let url = URL(string: baseURL + "/auth/validate") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        let result = try decoder.decode(AuthValidateResponse.self, from: data)
        jwtToken = jwt
        return ValidateResult(user: result.user, role: result.role)
    }

    /// Update user role on backend
    func updateUserRole(_ role: UserRole, jwt: String) async throws {
        guard let url = URL(string: baseURL + "/auth/role") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(RoleUpdateRequest(role: role.rawValue))

        let (_, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }

    /// Authenticate via Apple Sign-In
    func appleAuth(identityToken: String, userId: String, firstName: String?, lastName: String?, email: String?) async throws -> String {
        guard let url = URL(string: baseURL + "/auth/apple") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(AppleAuthRequest(
            identityToken: identityToken,
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            email: email
        ))

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        let result = try decoder.decode(AppleAuthResponse.self, from: data)
        guard let jwt = result.jwt else {
            throw NetworkError.serverError(0)
        }
        return jwt
    }

    /// Parse voice input into CRM entities via backend
    func parseVoiceCRM(
        text: String,
        timezone: String = "Asia/Irkutsk"
    ) async throws -> VoiceCRMResponse {
        let request = VoiceCRMRequest(text: text, timezone: timezone)

        guard let url = URL(string: baseURL + "/voice-crm") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where error.code == .timedOut {
            throw NetworkError.timeout
        } catch let error as URLError where error.code == .cannotConnectToHost
                                         || error.code == .notConnectedToInternet
                                         || error.code == .networkConnectionLost {
            throw NetworkError.noConnection
        } catch {
            throw NetworkError.unknown(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(VoiceCRMResponse.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }

    /// Search for masters by query and user location
    func searchMasters(
        query: String,
        latitude: Double,
        longitude: Double,
        radiusKm: Double = 50.0
    ) async throws -> SearchResponse {
        let request = SearchRequest(
            query: query,
            latitude: latitude,
            longitude: longitude,
            radiusKm: radiusKm
        )

        guard let url = URL(string: baseURL + "/search") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where error.code == .timedOut {
            throw NetworkError.timeout
        } catch let error as URLError where error.code == .cannotConnectToHost
                                         || error.code == .notConnectedToInternet
                                         || error.code == .networkConnectionLost {
            throw NetworkError.noConnection
        } catch {
            throw NetworkError.unknown(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(SearchResponse.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
}
