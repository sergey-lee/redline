import Foundation

enum OAuthUsageError: Error, LocalizedError {
    case noCredentials
    case unauthorized
    case http(Int)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "Claude Code isn't signed in on this Mac."
        case .unauthorized:
            return "Your Claude session token has expired."
        case .http(let code):
            return "Anthropic's usage API returned HTTP \(code)."
        case .badResponse:
            return "Couldn't read the usage response."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noCredentials:
            return "Open Terminal, run `claude`, and sign in. Then tap Try again."
        case .unauthorized:
            return "Open Terminal and run `claude` then `/login` to re-authenticate. Then tap Try again."
        case .http(let code):
            return code >= 500
                ? "Anthropic's API is having trouble. Wait a moment, then tap Try again."
                : "Run `claude` then `/login` to refresh access, then tap Try again."
        case .badResponse:
            return "Tap Try again. If it keeps failing, the usage API format may have changed — update the app."
        }
    }
}

enum OAuthUsageProvider {
    static func fetch(token: String) async throws -> OAuthUsage {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OAuthUsageError.badResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw OAuthUsageError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw OAuthUsageError.http(http.statusCode) }
        guard let usage = OAuthUsage.parse(data: data) else { throw OAuthUsageError.badResponse }
        return usage
    }
}
