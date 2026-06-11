import Foundation

/// A tiny, provider-agnostic usage snapshot shared from the app to the
/// WidgetKit extension via the App Group container. The widget process is
/// sandboxed and can't read the keychain or ~/.claude, so the app writes this
/// and the widget reads it.
struct UsageSnapshot: Codable, Equatable {
    var provider: String          // "Claude" | "Codex"
    var fiveHour: Double          // 0–100
    var weekly: Double            // 0–100
    var fiveHourResetsAt: Date?
    var weeklyResetsAt: Date?
    var updatedAt: Date

    static let placeholder = UsageSnapshot(
        provider: "Claude", fiveHour: 42, weekly: 31,
        fiveHourResetsAt: nil, weeklyResetsAt: nil, updatedAt: Date(timeIntervalSince1970: 0)
    )
}

enum SnapshotStore {
    static let appGroup = "group.net.alienminds.redline"
    private static let filename = "usage-snapshot.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(filename)
    }

    static func write(_ snapshot: UsageSnapshot) {
        guard let url = fileURL,
              let data = try? JSONEncoder.iso.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func read() -> UsageSnapshot? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder.iso.decode(UsageSnapshot.self, from: data) else { return nil }
        return snap
    }
}

extension JSONEncoder {
    static var iso: JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }
}
extension JSONDecoder {
    static var iso: JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }
}
