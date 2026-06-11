import WidgetKit
import SwiftUI

struct RedlineEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> RedlineEntry {
        RedlineEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (RedlineEntry) -> Void) {
        completion(RedlineEntry(date: Date(), snapshot: SnapshotStore.read() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RedlineEntry>) -> Void) {
        let snap = SnapshotStore.read() ?? .placeholder
        let entry = RedlineEntry(date: Date(), snapshot: snap)
        // The app reloads timelines on every refresh; this is just a fallback
        // cadence so the relative reset captions stay roughly fresh.
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct RedlineWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: RedlineEntry

    private var s: UsageSnapshot { entry.snapshot }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            default: medium
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.20, green: 0.17, blue: 0.16),
                         Color(red: 0.08, green: 0.07, blue: 0.065)],
                startPoint: .top, endPoint: .bottom)
        }
    }

    private var small: some View {
        VStack(spacing: 5) {
            GaugeRing(percent: s.fiveHour, caption: "5-HOUR", size: 92, lineWidth: 10)
            if let r = Format.relativeReset(s.fiveHourResetsAt) {
                Text(r).font(.system(size: 9)).foregroundStyle(Theme.subtle)
            }
            refreshButton
        }
    }

    private var medium: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    GaugeRing(percent: s.fiveHour, caption: "5-HOUR", size: 88, lineWidth: 10)
                    if let r = Format.relativeReset(s.fiveHourResetsAt) {
                        Text(r).font(.system(size: 9)).foregroundStyle(Theme.subtle)
                    }
                }
                VStack(spacing: 4) {
                    GaugeRing(percent: s.weekly, caption: "WEEKLY", size: 88, lineWidth: 10)
                    Text(s.provider).font(.system(size: 9)).foregroundStyle(Theme.subtle)
                }
            }
            HStack(spacing: 8) {
                refreshButton
                if s.updatedAt.timeIntervalSince1970 > 0 {
                    Text("updated \(s.updatedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 8)).foregroundStyle(Theme.subtle)
                }
            }
        }
    }

    private var refreshButton: some View {
        Button(intent: RefreshIntent()) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise").font(.system(size: 9, weight: .semibold))
                Text("Refresh").font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }
}

struct RedlineWidget: Widget {
    let kind = "RedlineWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RedlineWidgetView(entry: entry)
        }
        .configurationDisplayName("Redline")
        .description("Your Claude / Codex usage at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct RedlineWidgetBundle: WidgetBundle {
    var body: some Widget { RedlineWidget() }
}
