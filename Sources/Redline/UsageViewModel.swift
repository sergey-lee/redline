import Foundation
import SwiftUI
import Combine
import WidgetKit

enum Provider: String, CaseIterable, Identifiable {
    case claude = "Claude"
    case codex = "Codex"
    var id: String { rawValue }
}

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var usage: OAuthUsage?
    @Published var codex: CodexStatus?
    @Published var today: DayStats = DayStats()
    @Published var burnRate: BurnRate?
    @Published var sparkline: [Double] = []
    @Published var errorMessage: String?
    @Published var errorFix: String?
    @Published var lastUpdated: Date?
    @Published var isRefreshing = false

    @AppStorage("provider") var providerRaw: String = Provider.claude.rawValue
    @AppStorage("alertThreshold") var alertThreshold: Double = 85
    @AppStorage("refreshSeconds") var refreshSeconds: Double = 60
    @AppStorage("showWidget") var showWidget: Bool = false
    @AppStorage("widgetSize") var widgetSizeRaw: String = WidgetSize.medium.rawValue

    var provider: Provider {
        get { Provider(rawValue: providerRaw) ?? .claude }
        set { providerRaw = newValue.rawValue }
    }

    var widgetSize: WidgetSize {
        get { WidgetSize(rawValue: widgetSizeRaw) ?? .medium }
        set { widgetSizeRaw = newValue.rawValue }
    }

    private let history = HistoryStore()
    private var timer: Timer?
    private var firedAlertThisWindow = false
    private lazy var widget = DesktopWidgetController(vm: self)

    init() {
        sparkline = history.recentFiveHourSeries()
        burnRate = history.burnRate()
    }

    func applyWidgetVisibility() {
        widget.setVisible(showWidget, size: widgetSize)
    }

    func toggleWidget(_ on: Bool) {
        showWidget = on
        widget.setVisible(on, size: widgetSize)
    }

    func setWidgetSize(_ size: WidgetSize) {
        widgetSize = size
        if showWidget { widget.updateSize(size) }
    }

    private var didStart = false
    func start() {
        guard !didStart else { return }
        didStart = true
        RefreshBridge.onRefresh = { [weak self] in Task { await self?.refresh() } }
        RefreshBridge.start()
        Task { await refresh() }
        scheduleTimer()
        applyWidgetVisibility()
    }

    func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: max(refreshSeconds, 20), repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    /// Headline percentage shown in the menu bar.
    var headlinePercent: Double {
        switch provider {
        case .claude: return usage?.headlineUtilization ?? 0
        case .codex:
            return max(codex?.primary?.usedPercent ?? 0, codex?.secondary?.usedPercent ?? 0)
        }
    }

    var statusColor: Color {
        let p = headlinePercent
        if p >= 90 { return .red }
        if p >= 70 { return .orange }
        if p >= 40 { return .yellow }
        return .green
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // Local data involves scanning many files — do it off the main actor so
        // the UI never janks.
        async let todayTask = Task.detached(priority: .utility) { TranscriptAnalyzer.todayStats() }.value
        async let codexTask = Task.detached(priority: .utility) { CodexProvider.currentStatus() }.value
        today = await todayTask
        codex = await codexTask

        do {
            let token = try await TokenManager.shared.validAccessToken()
            let fresh = try await fetchUsageWithRetry(token: token)
            usage = fresh
            errorMessage = nil
            errorFix = nil
            history.record(fresh)
            sparkline = history.recentFiveHourSeries()
            burnRate = history.burnRate()
            evaluateAlert(fresh)
        } catch {
            if provider == .claude {
                let le = error as? LocalizedError
                errorMessage = le?.errorDescription ?? error.localizedDescription
                errorFix = le?.recoverySuggestion
                    ?? "Check your connection and tap Try again. If it persists, re-run `claude` /login."
            }
        }
        lastUpdated = Date()
        publishSnapshot()
    }

    /// Hand the current provider's numbers to the WidgetKit extension via the
    /// App Group, then ask the system to refresh the widget.
    func publishSnapshot() {
        let snap: UsageSnapshot
        switch provider {
        case .claude:
            snap = UsageSnapshot(
                provider: "Claude",
                fiveHour: usage?.fiveHour?.utilization ?? 0,
                weekly: usage?.sevenDay?.utilization ?? 0,
                fiveHourResetsAt: usage?.fiveHour?.resetsAt,
                weeklyResetsAt: usage?.sevenDay?.resetsAt,
                updatedAt: Date()
            )
        case .codex:
            snap = UsageSnapshot(
                provider: "Codex",
                fiveHour: codex?.primary?.usedPercent ?? 0,
                weekly: codex?.secondary?.usedPercent ?? 0,
                fiveHourResetsAt: codex?.primary?.resetsAt,
                weeklyResetsAt: codex?.secondary?.resetsAt,
                updatedAt: Date()
            )
        }
        SnapshotStore.write(snap)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Fetches usage; on a 401 it forces one token refresh and retries once.
    private func fetchUsageWithRetry(token: String) async throws -> OAuthUsage {
        do {
            return try await OAuthUsageProvider.fetch(token: token)
        } catch OAuthUsageError.unauthorized {
            let refreshed = try await TokenManager.shared.forceRefresh()
            return try await OAuthUsageProvider.fetch(token: refreshed)
        }
    }

    private func evaluateAlert(_ usage: OAuthUsage) {
        let p = usage.headlineUtilization
        if p >= alertThreshold {
            if !firedAlertThisWindow {
                firedAlertThisWindow = true
                Notifier.send(
                    title: "Claude usage at \(Format.percent(p))",
                    body: alertBody(usage)
                )
            }
        } else if p < alertThreshold - 10 {
            firedAlertThisWindow = false // reset hysteresis once we drop clear
        }
    }

    private func alertBody(_ usage: OAuthUsage) -> String {
        if let reset = Format.relativeReset(usage.fiveHour?.resetsAt) {
            return "5-hour window — \(reset)."
        }
        return "Approaching your usage limit."
    }
}
