import Foundation

/// Persists a rolling window of usage samples to disk so we can compute burn
/// rate and draw a sparkline across app restarts.
final class HistoryStore {
    private let url: URL
    private let maxSamples = 2_000
    private(set) var samples: [UsageSample]

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaudeMeter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("history.json")

        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([UsageSample].self, from: data) {
            samples = decoded
        } else {
            samples = []
        }
    }

    func record(_ usage: OAuthUsage, at date: Date = Date()) {
        let sample = UsageSample(
            date: date,
            fiveHour: usage.fiveHour?.utilization ?? 0,
            sevenDay: usage.sevenDay?.utilization ?? 0
        )
        samples.append(sample)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
        persist()
    }

    /// Burn rate over the trailing `window`, using the 5-hour utilization series.
    /// Resets (a drop in utilization) start a fresh segment so we don't average
    /// across a window rollover.
    func burnRate(window: TimeInterval = 3600, now: Date = Date()) -> BurnRate? {
        let recent = samples.filter { now.timeIntervalSince($0.date) <= window }
        guard recent.count >= 2 else { return nil }

        // Find the last monotonic-increasing segment.
        var segment: [UsageSample] = [recent[0]]
        for s in recent.dropFirst() {
            if s.fiveHour + 0.01 < segment.last!.fiveHour {
                segment = [s] // reset detected
            } else {
                segment.append(s)
            }
        }
        guard let first = segment.first, let last = segment.last,
              last.date > first.date else { return nil }

        let deltaPercent = last.fiveHour - first.fiveHour
        let deltaHours = last.date.timeIntervalSince(first.date) / 3600
        guard deltaHours > 0 else { return nil }
        let perHour = deltaPercent / deltaHours

        var exhaustion: Date?
        if perHour > 0.1 {
            let remaining = 100 - last.fiveHour
            let hoursLeft = remaining / perHour
            exhaustion = now.addingTimeInterval(hoursLeft * 3600)
        }
        return BurnRate(percentPerHour: perHour, projectedExhaustion: exhaustion)
    }

    func recentFiveHourSeries(window: TimeInterval = 5 * 3600, now: Date = Date()) -> [Double] {
        samples.filter { now.timeIntervalSince($0.date) <= window }.map { $0.fiveHour }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(samples) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
