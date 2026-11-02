import Foundation
import Security

/// One rate-limit window (e.g. the 5-hour session or the weekly limit).
nonisolated struct UsageWindow: Decodable, Sendable, Equatable {
    /// Percent of the limit used, 0...100.
    let utilization: Double
    let resetsAt: Date?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

nonisolated struct UsageSnapshot: Decodable, Sendable, Equatable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

nonisolated enum UsageError: LocalizedError {
    case noCredentials
    case unauthorized
    case http(Int)
    case network(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .noCredentials: "Claude Code login not found in Keychain. Run `claude` and sign in."
        case .unauthorized: "Login expired. Run `claude` once to refresh it."
        case .http(let code): "Usage request failed (HTTP \(code))."
        case .network(let message): "Network error: \(message)"
        case .decoding: "Unexpected response from the usage API."
        }
    }
}

/// Reads the Claude Code OAuth token from the Keychain and queries the usage endpoint.
/// The endpoint is undocumented, so decoding is deliberately tolerant.
nonisolated enum UsageService {
    private static let keychainService = "Claude Code-credentials"
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetch() async throws -> UsageSnapshot {
        let token = try await readAccessToken()

        var request = URLRequest(url: usageURL, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageError.network(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw http.statusCode == 401 ? UsageError.unauthorized : UsageError.http(http.statusCode)
        }
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> UsageSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            // Server sends microsecond fractions, e.g. 2026-11-02T06:40:00.136381+00:00.
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            if let date = withFraction.date(from: string) ?? plain.date(from: string) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Bad date: \(string)"))
        }
        do {
            return try decoder.decode(UsageSnapshot.self, from: data)
        } catch {
            throw UsageError.decoding
        }
    }

    /// Keychain reads can block on the access prompt, so keep them off the main actor.
    @concurrent
    private static func readAccessToken() async throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { throw UsageError.noCredentials }
        return token
    }
}
