import Foundation

enum Format {
    static func tokens(_ n: Int) -> String {
        let v = Double(n)
        switch v {
        case 1_000_000...:
            return String(format: "%.2fM", v / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", v / 1_000)
        default:
            return "\(n)"
        }
    }

    static func usd(_ v: Double) -> String {
        if v >= 100 { return String(format: "$%.0f", v) }
        if v >= 1 { return String(format: "$%.2f", v) }
        return String(format: "$%.3f", v)
    }

    static func percent(_ v: Double) -> String {
        String(format: "%.0f%%", v)
    }

    /// Human-readable label for a raw usage-window key so the UI never shows
    /// identifiers like "seven_day_opus".
    static func windowLabel(_ key: String) -> String {
        switch key {
        case "five_hour": return "5-HOUR"
        case "seven_day": return "WEEKLY"
        case "seven_day_oauth_apps": return "APPS"
        default:
            // Model-scoped weekly windows (seven_day_sonnet, seven_day_opus, …)
            // show just the model name, e.g. "SONNET" / "OPUS".
            if key.hasPrefix("seven_day_") {
                return String(key.dropFirst("seven_day_".count))
                    .replacingOccurrences(of: "_", with: " ")
                    .uppercased()
            }
            return key.replacingOccurrences(of: "_", with: " ").uppercased()
        }
    }

    static func windowIcon(_ key: String) -> String {
        switch key {
        case "five_hour": return "clock"
        case "seven_day": return "calendar"
        case "seven_day_opus": return "o.square"
        case "seven_day_sonnet": return "s.square"
        case "seven_day_haiku": return "h.square"
        default: return "square"
        }
    }

    /// "resets in 2h 14m" / "resets in 43m"
    static func relativeReset(_ date: Date?, now: Date = Date()) -> String? {
        guard let date else { return nil }
        let secs = date.timeIntervalSince(now)
        guard secs > 0 else { return "resetting…" }
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        if h > 0 { return "resets in \(h)h \(m)m" }
        return "resets in \(m)m"
    }

    static func eta(_ date: Date?, now: Date = Date()) -> String? {
        guard let date else { return nil }
        let secs = date.timeIntervalSince(now)
        guard secs > 0 else { return nil }
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        if h >= 24 { return "\(h / 24)d \(h % 24)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
