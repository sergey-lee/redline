import Foundation

/// Reads OpenAI Codex CLI rate limits from the newest session transcript
/// (~/.codex/sessions/**/*.jsonl). Codex writes a `rate_limits` object with
/// `used_percent` for its primary (5h) and secondary (weekly) windows.
enum CodexProvider {

    static func currentStatus() -> CodexStatus? {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else { return nil }

        guard let newest = newestSessionFile(in: root) else { return nil }
        guard let tail = readTail(of: newest, maxBytes: 256 * 1024) else { return nil }

        // Scan lines from the end for the most recent rate_limits payload.
        for lineText in tail.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            guard lineText.contains("rate_limits") else { continue }
            guard let data = lineText.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            if let limits = findRateLimits(in: obj) {
                let ts = (obj["timestamp"] as? String).flatMap(ISO8601.parse)
                let primary = parseLimit(limits["primary"] as? [String: Any], observedAt: ts)
                let secondary = parseLimit(limits["secondary"] as? [String: Any], observedAt: ts)
                if primary != nil || secondary != nil {
                    return CodexStatus(primary: primary, secondary: secondary, observedAt: ts)
                }
            }
        }
        return nil
    }

    private static func newestSessionFile(in root: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var newest: (URL, Date)?
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate
            else { continue }
            if newest == nil || modified > newest!.1 {
                newest = (url, modified)
            }
        }
        return newest?.0
    }

    private static func readTail(of url: URL, maxBytes: Int) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let offset = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? handle.seek(toOffset: offset)
        guard let data = try? handle.readToEnd() else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Recursively search a JSON object for a "rate_limits" dictionary.
    private static func findRateLimits(in obj: [String: Any], depth: Int = 0) -> [String: Any]? {
        guard depth < 5 else { return nil }
        if let limits = obj["rate_limits"] as? [String: Any] { return limits }
        for value in obj.values {
            if let sub = value as? [String: Any],
               let found = findRateLimits(in: sub, depth: depth + 1) {
                return found
            }
        }
        return nil
    }

    private static func parseLimit(_ dict: [String: Any]?, observedAt: Date?) -> CodexRateLimit? {
        guard let dict else { return nil }
        let used = (dict["used_percent"] as? Double)
            ?? (dict["used_percent"] as? Int).map(Double.init)
        guard let used else { return nil }

        var resetsAt: Date?
        if let seconds = (dict["resets_in_seconds"] as? Double)
            ?? (dict["resets_in_seconds"] as? Int).map(Double.init) {
            resetsAt = (observedAt ?? Date()).addingTimeInterval(seconds)
        }
        let windowMinutes = (dict["window_minutes"] as? Int)
            ?? (dict["window_minutes"] as? Double).map(Int.init)

        return CodexRateLimit(
            usedPercent: min(max(used, 0), 100),
            windowMinutes: windowMinutes,
            resetsAt: resetsAt
        )
    }
}
