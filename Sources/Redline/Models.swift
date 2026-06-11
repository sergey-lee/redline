import Foundation

// MARK: - Usage windows from the OAuth usage endpoint

struct UsageWindow: Equatable {
    let utilization: Double   // 0–100
    let resetsAt: Date?
}

struct OAuthUsage: Equatable {
    var windows: [String: UsageWindow]

    var fiveHour: UsageWindow? { windows["five_hour"] }
    var sevenDay: UsageWindow? { windows["seven_day"] }
    var sevenDayOpus: UsageWindow? { windows["seven_day_opus"] }

    /// Any additional windows the API returns that we don't model explicitly.
    var extraWindows: [(key: String, window: UsageWindow)] {
        windows
            .filter { !["five_hour", "seven_day", "seven_day_opus"].contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { (key: $0.key, window: $0.value) }
    }

    /// Every window except the 5-hour one, ordered for display: the overall
    /// weekly first, then model-scoped weeklies (Opus, Sonnet, …) alphabetically.
    var secondaryWindows: [(key: String, window: UsageWindow)] {
        let order: (String) -> Int = { key in
            switch key {
            case "seven_day": return 0
            case "seven_day_opus": return 1
            case "seven_day_sonnet": return 2
            default: return 3
            }
        }
        return windows
            .filter { $0.key != "five_hour" }
            .sorted { (order($0.key), $0.key) < (order($1.key), $1.key) }
            .map { (key: $0.key, window: $0.value) }
    }

    /// Headline number for the menu bar: the most constrained limit.
    var headlineUtilization: Double {
        [fiveHour?.utilization, sevenDay?.utilization, sevenDayOpus?.utilization]
            .compactMap { $0 }
            .max() ?? 0
    }

    static func parse(data: Data) -> OAuthUsage? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var windows: [String: UsageWindow] = [:]

        func walk(_ dict: [String: Any], prefix: String, depth: Int) {
            guard depth < 3 else { return }
            for (key, value) in dict {
                guard let sub = value as? [String: Any] else { continue }
                let util = (sub["utilization"] as? Double)
                    ?? (sub["utilization"] as? Int).map(Double.init)
                if let util {
                    let resets = (sub["resets_at"] as? String).flatMap(ISO8601.parse)
                    windows[prefix + key] = UsageWindow(
                        utilization: min(max(util, 0), 100),
                        resetsAt: resets
                    )
                } else {
                    walk(sub, prefix: prefix + key + ".", depth: depth + 1)
                }
            }
        }
        walk(obj, prefix: "", depth: 0)
        return windows.isEmpty ? nil : OAuthUsage(windows: windows)
    }
}

enum ISO8601 {
    private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()

    static func parse(_ s: String) -> Date? {
        withFractional.date(from: s) ?? plain.date(from: s)
    }
}

// MARK: - Keychain credentials

struct ClaudeCredentials {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let subscriptionType: String?

    /// Treat as expired a couple of minutes early to avoid racing the clock.
    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt.addingTimeInterval(-120)
    }
}

// MARK: - Local transcript analytics

struct ModelStats: Identifiable {
    var id: String { model }
    let model: String
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheWriteTokens: Int = 0
    var cost: Double = 0
    var messages: Int = 0
}

struct DayStats {
    var totalCost: Double = 0
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheWriteTokens: Int = 0
    var messages: Int = 0
    var perModel: [ModelStats] = []
}

// MARK: - Codex

struct CodexRateLimit {
    let usedPercent: Double
    let windowMinutes: Int?
    let resetsAt: Date?
}

struct CodexStatus {
    let primary: CodexRateLimit?     // usually the 5h window
    let secondary: CodexRateLimit?   // usually the weekly window
    let observedAt: Date?
}

// MARK: - History sample (for burn rate + sparkline)

struct UsageSample: Codable, Equatable {
    let date: Date
    let fiveHour: Double
    let sevenDay: Double
}

struct BurnRate {
    let percentPerHour: Double
    let projectedExhaustion: Date?   // when the 5h window hits 100% at the current pace
}

extension Format {
    /// Burn-rate label, e.g. "12%/h". App-only: depends on BurnRate.
    static func burn(_ rate: BurnRate?) -> String? {
        guard let rate, rate.percentPerHour > 0.1 else { return nil }
        return String(format: "%.0f%%/h", rate.percentPerHour)
    }
}
