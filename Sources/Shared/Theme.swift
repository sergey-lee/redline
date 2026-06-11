import SwiftUI

/// Warm charcoal surfaces with an orange→red status ramp and muted gray labels.
enum Theme {
    static let background = Color(red: 0.13, green: 0.12, blue: 0.115)   // warm near-black
    static let card = Color(red: 0.17, green: 0.16, blue: 0.155)
    static let cardMuted = Color(red: 0.15, green: 0.14, blue: 0.135)
    static let track = Color.white.opacity(0.08)
    static let label = Color.white.opacity(0.45)
    static let subtle = Color.white.opacity(0.30)
    static let text = Color.white.opacity(0.92)

    static let green = Color(red: 0.36, green: 0.82, blue: 0.55)
    static let amber = Color(red: 0.97, green: 0.70, blue: 0.27)

    /// Status color along the green→yellow→orange→red ramp.
    static func status(_ percent: Double) -> Color {
        switch percent {
        case ..<40: return green
        case ..<70: return amber
        case ..<90: return Color(red: 0.95, green: 0.45, blue: 0.20)   // orange
        default:    return Color(red: 0.93, green: 0.28, blue: 0.24)    // red
        }
    }

    /// The pixel-ish title face. Falls back gracefully if unavailable; a
    /// monospaced bold weight approximates the App Store's bitmap font.
    static func pixelTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .monospaced)
    }
}
