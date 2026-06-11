import Foundation

enum TokenError: Error, LocalizedError {
    case noCredentials
    case refreshFailed(String)
    case loginRequired

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "Claude Code isn't signed in on this Mac."
        case .loginRequired:
            return "Your Claude session has expired."
        case .refreshFailed:
            return "Couldn't refresh your Claude token."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noCredentials:
            return "Open Terminal, run `claude`, and sign in. Then tap Try again."
        case .loginRequired:
            return "Open Terminal and run `claude` then `/login` to re-authenticate. Then tap Try again."
        case .refreshFailed(let msg):
            return "Check your internet connection, or re-run `/login` in Claude Code, then tap Try again. (\(msg))"
        }
    }
}

/// Provides a valid Claude OAuth access token, refreshing via the rotating
/// refresh-token grant and writing the new pair back into the keychain so
/// Claude Code stays in sync.
actor TokenManager {
    static let shared = TokenManager()

    // Public OAuth client id used by Claude Code.
    private let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private let tokenEndpoint = URL(string: "https://api.anthropic.com/v1/oauth/token")!

    func validAccessToken() async throws -> String {
        guard let creds = KeychainService.readClaudeCredentials() else {
            throw TokenError.noCredentials
        }
        if !creds.isExpired {
            return creds.accessToken
        }
        guard let refresh = creds.refreshToken else {
            throw TokenError.loginRequired
        }
        return try await performRefresh(using: refresh)
    }

    /// Forces a refresh (used when the API rejects an otherwise-unexpired token).
    func forceRefresh() async throws -> String {
        guard let creds = KeychainService.readClaudeCredentials(),
              let refresh = creds.refreshToken else {
            throw TokenError.loginRequired
        }
        return try await performRefresh(using: refresh)
    }

    private func performRefresh(using refreshToken: String) async throws -> String {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        let payload: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TokenError.refreshFailed("no response")
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TokenError.refreshFailed("bad response")
        }
        if http.statusCode == 400 || http.statusCode == 401,
           let err = obj["error"] as? String, err.contains("grant") {
            throw TokenError.loginRequired
        }
        guard
            (200..<300).contains(http.statusCode),
            let access = obj["access_token"] as? String,
            let newRefresh = obj["refresh_token"] as? String,
            let expiresIn = (obj["expires_in"] as? Double) ?? (obj["expires_in"] as? Int).map(Double.init)
        else {
            let msg = (obj["error_description"] as? String) ?? (obj["error"] as? String) ?? "HTTP \(http.statusCode)"
            throw TokenError.refreshFailed(msg)
        }

        let expiresAtMs = (Date().timeIntervalSince1970 + expiresIn) * 1000
        // Critical: persist the rotated refresh token immediately.
        KeychainService.writeRefreshedTokens(
            accessToken: access,
            refreshToken: newRefresh,
            expiresAtMs: expiresAtMs
        )
        return access
    }
}
