import Foundation

/// Parses local Claude Code transcripts (~/.claude/projects/**/*.jsonl) and
/// aggregates token usage and estimated cost for the current day.
enum TranscriptAnalyzer {

    private struct Line: Decodable {
        let type: String?
        let timestamp: String?
        let requestId: String?
        let message: Message?

        struct Message: Decodable {
            let id: String?
            let model: String?
            let usage: Usage?
        }

        struct Usage: Decodable {
            let inputTokens: Int?
            let outputTokens: Int?
            let cacheCreationInputTokens: Int?
            let cacheReadInputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
                case cacheReadInputTokens = "cache_read_input_tokens"
            }
        }
    }

    static func todayStats(now: Date = Date()) -> DayStats {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)

        var stats = DayStats()
        var perModel: [String: ModelStats] = [:]
        var seen = Set<String>()

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return stats }

        let decoder = JSONDecoder()

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            guard
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                values.isRegularFile == true,
                let modified = values.contentModificationDate,
                modified >= dayStart
            else { continue }

            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }

            for lineText in raw.split(separator: "\n", omittingEmptySubsequences: true) {
                // Cheap pre-filter before JSON decoding.
                guard lineText.contains("\"usage\""), lineText.contains("\"assistant\"") else { continue }
                guard let data = lineText.data(using: .utf8),
                      let line = try? decoder.decode(Line.self, from: data),
                      line.type == "assistant",
                      let usage = line.message?.usage
                else { continue }

                guard let ts = line.timestamp.flatMap(ISO8601.parse), ts >= dayStart else { continue }

                // Dedupe retried/streamed duplicates by message id + request id.
                if let msgId = line.message?.id {
                    let key = msgId + ":" + (line.requestId ?? "")
                    if seen.contains(key) { continue }
                    seen.insert(key)
                }

                let model = line.message?.model ?? "unknown"
                let input = usage.inputTokens ?? 0
                let output = usage.outputTokens ?? 0
                let cacheWrite = usage.cacheCreationInputTokens ?? 0
                let cacheRead = usage.cacheReadInputTokens ?? 0
                let cost = Pricing.cost(
                    model: model, input: input, output: output,
                    cacheWrite: cacheWrite, cacheRead: cacheRead
                )

                stats.totalCost += cost
                stats.inputTokens += input
                stats.outputTokens += output
                stats.cacheWriteTokens += cacheWrite
                stats.cacheReadTokens += cacheRead
                stats.messages += 1

                var m = perModel[model] ?? ModelStats(model: model)
                m.inputTokens += input
                m.outputTokens += output
                m.cacheWriteTokens += cacheWrite
                m.cacheReadTokens += cacheRead
                m.cost += cost
                m.messages += 1
                perModel[model] = m
            }
        }

        stats.perModel = perModel.values.sorted { $0.cost > $1.cost }
        return stats
    }
}
