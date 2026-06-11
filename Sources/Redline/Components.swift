import SwiftUI

/// A compact metric card (e.g. WEEKLY / SONNET) with an icon, percentage, a
/// thin progress bar, and a reset caption.
struct MetricCard: View {
    let systemIcon: String
    let title: String
    let percent: Double
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: systemIcon)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.subtle)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.label)
                Spacer()
                Text(Format.percent(percent))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.status(percent))
            }
            ProgressTrack(percent: percent)
            Text(caption ?? " ")
                .font(.system(size: 9))
                .foregroundStyle(Theme.subtle)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(cornerRadius: 10)
    }
}

/// Full-width muted card for a disabled/empty metric (e.g. EXTRA USAGE — Off).
struct MutedRow: View {
    let systemIcon: String
    let title: String
    let trailing: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: systemIcon).font(.system(size: 9)).foregroundStyle(Theme.subtle)
                Text(title).font(.system(size: 10, weight: .semibold)).tracking(0.5).foregroundStyle(Theme.label)
                Spacer()
                Text(trailing).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.subtle)
            }
            ProgressTrack(percent: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 10)
        .opacity(0.7)
    }
}

struct ProgressTrack: View {
    let percent: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(Theme.status(percent).gradient)
                    .frame(width: max(percent > 0 ? 3 : 0, geo.size.width * percent / 100))
            }
        }
        .frame(height: 4)
    }
}

/// Burn-rate card: pace verdict + emoji + a filled-area sparkline.
struct PaceCard: View {
    let pace: Pace
    let series: [Double]

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f%%", pace.perHour))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("per hour").font(.system(size: 9)).foregroundStyle(Theme.subtle)
                }
                HStack(spacing: 4) {
                    Text(pace.state.emoji).font(.system(size: 10))
                    Text(pace.state.label)
                        .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                        .foregroundStyle(pace.state.color)
                }
                Text(pace.detail).font(.system(size: 9)).foregroundStyle(Theme.subtle)
            }
            Spacer(minLength: 4)
            AreaSparkline(values: series, color: pace.state.color)
                .frame(width: 96, height: 40)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 10, tint: pace.state.color)
    }
}

/// Filled-area sparkline used in the burn-rate card.
struct AreaSparkline: View {
    let values: [Double]
    var color: Color

    var body: some View {
        GeometryReader { geo in
            if values.count >= 2 {
                let maxV = max(values.max() ?? 1, 1)
                let pts = points(in: geo.size, maxV: maxV)
                ZStack {
                    // Fill
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                        for pt in pts { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [color.opacity(0.45), color.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom))
                    // Stroke
                    Path { p in
                        p.move(to: pts[0])
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
            } else {
                Text("collecting…")
                    .font(.system(size: 9)).foregroundStyle(Theme.subtle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }

    private func points(in size: CGSize, maxV: Double) -> [CGPoint] {
        let stepX = size.width / CGFloat(max(values.count - 1, 1))
        return values.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) * stepX, y: size.height * (1 - CGFloat(v / maxV)))
        }
    }
}

/// Custom glass segmented control — consistent across OS versions and on-brand,
/// unlike the system segmented Picker.
struct GlassSegmented<T: Hashable>: View {
    let options: [(value: T, label: String)]
    @Binding var selection: T
    var onChange: ((T) -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { opt in
                let isSelected = opt.value == selection
                Text(opt.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.text : Theme.label)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.white.opacity(0.10))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isSelected else { return }
                        withAnimation(.easeOut(duration: 0.15)) { selection = opt.value }
                        onChange?(opt.value)
                    }
            }
        }
        .padding(3)
        .glassCard(cornerRadius: 10)
    }
}

struct StatPill: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Theme.text)
            Text(label).font(.system(size: 9)).foregroundStyle(Theme.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .glassCard(cornerRadius: 8)
    }
}
