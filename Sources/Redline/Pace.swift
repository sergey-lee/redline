import SwiftUI

enum PaceState {
    case onTrack
    case underPace
    case overPace

    var label: String {
        switch self {
        case .onTrack: return "ON TRACK"
        case .underPace: return "UNDER PACE"
        case .overPace: return "OVER PACE"
        }
    }

    var emoji: String {
        switch self {
        case .onTrack: return "✅"
        case .underPace: return "🐢"
        case .overPace: return "🐇"
        }
    }

    var color: Color {
        switch self {
        case .onTrack: return Theme.green
        case .underPace: return Theme.amber
        case .overPace: return Color(red: 0.95, green: 0.42, blue: 0.22)
        }
    }
}

struct Pace {
    let state: PaceState
    let perHour: Double
    let detail: String

    /// Derive a pace verdict from the current burn rate and how full the
    /// 5-hour window already is, relative to its reset time.
    static func evaluate(burn: BurnRate?, currentPercent: Double, resetsAt: Date?, now: Date = Date()) -> Pace? {
        guard let burn else { return nil }
        let perHour = burn.percentPerHour

        // How long until the window resets (capped to the 5-hour horizon).
        let hoursToReset: Double = {
            guard let resetsAt else { return 5 }
            return max(0.05, min(5, resetsAt.timeIntervalSince(now) / 3600))
        }()

        let projected = currentPercent + perHour * hoursToReset

        if perHour < 1 {
            return Pace(state: .onTrack, perHour: perHour, detail: "Well-paced for this window.")
        }
        if projected >= 100, let eta = burn.projectedExhaustion, eta < (resetsAt ?? now.addingTimeInterval(5 * 3600)) {
            let mins = max(1, Int(eta.timeIntervalSince(now) / 60))
            let etaText = mins >= 60 ? "~\(mins / 60)h \(mins % 60)m" : "~\(mins)min"
            return Pace(state: .overPace, perHour: perHour, detail: "Could hit the limit in \(etaText).")
        }
        return Pace(state: .underPace, perHour: perHour, detail: "Plenty of capacity remaining.")
    }
}
