//
//  NetworkManager.swift
//  SoloStyle
//
//  Network layer for SoloStyle API (async/await)
//

import Foundation

// MARK: - API Models

struct SearchRequest: Codable, Sendable {
    let query: String
    let latitude: Double
    let longitude: Double
    let radiusKm: Double

    enum CodingKeys: String, CodingKey {
        case query, latitude, longitude
        case radiusKm = "radius_km"
    }
}

struct SearchResponse: Codable, Sendable {
    let answer: String
    let masters: [MasterResult]
}

struct MasterResult: Codable, Sendable, Identifiable {
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

struct VoiceCRMRequest: Codable, Sendable {
    let text: String
    let timezone: String
}

struct VoiceCRMResponse: Codable, Sendable {
    let success: Bool
    let entities: ParsedEntity
    let summary: String
}

struct ParsedEntity: Codable, Sendable {
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

// MARK: - Network Errors

enum NetworkError: LocalizedError, Sendable {
    case invalidURL
    case noConnection
    case serverError(Int)
    case decodingError
    case timeout
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

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
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
