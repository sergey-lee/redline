import Foundation
import Security

enum KeychainService {
    static let service = "Claude Code-credentials"

    /// Reads the OAuth credentials that Claude Code stores in the login keychain.
    /// The first read triggers a one-time macOS permission dialog — choose "Always Allow".
    static func readClaudeCredentials() -> ClaudeCredentials? {
        guard let root = readRoot(),
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { return nil }

        return ClaudeCredentials(
            accessToken: token,
            refreshToken: oauth["refreshToken"] as? String,
            expiresAt: msToDate(oauth["expiresAt"]),
            subscriptionType: oauth["subscriptionType"] as? String
        )
    }

    /// Reads the full credentials blob so we can mutate and write it back
    /// without clobbering fields we don't model (rateLimitTier, scopes, …).
    static func readRoot() -> [String: Any]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Writes refreshed tokens back into Claude Code's keychain item, preserving
    /// every other field. Keeping the item in sync means Claude Code keeps working
    /// after this app rotates the (single-use) refresh token.
    @discardableResult
    static func writeRefreshedTokens(accessToken: String, refreshToken: String, expiresAtMs: Double) -> Bool {
        guard var root = readRoot(),
              var oauth = root["claudeAiOauth"] as? [String: Any]
        else { return false }

        oauth["accessToken"] = accessToken
        oauth["refreshToken"] = refreshToken
        oauth["expiresAt"] = expiresAtMs
        root["claudeAiOauth"] = oauth

        guard let data = try? JSONSerialization.data(withJSONObject: root) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        return status == errSecSuccess
    }

    private static func msToDate(_ value: Any?) -> Date? {
        guard let ms = (value as? Double) ?? (value as? Int).map(Double.init) else { return nil }
        return Date(timeIntervalSince1970: ms > 1e12 ? ms / 1000 : ms)
    }
}
