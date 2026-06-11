import SwiftUI

struct MenuContentView: View {
    @ObservedObject var vm: UsageViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if showSettings {
                SettingsView(vm: vm)
            } else {
                switch vm.provider {
                case .claude: claudeSection
                case .codex: codexSection
                }
                Divider().overlay(Theme.track)
                todaySection
            }

            footer
        }
        .padding(16)
        .frame(width: 320)
        .background(windowBackground)
        .background(WindowAccessor { window in
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
        })
        .preferredColorScheme(.dark)
    }

    /// Glass on macOS 26 (matches the widget), frosted NSVisualEffectView below.
    @ViewBuilder
    private var windowBackground: some View {
        if GlassEnv.forceSolid {
            RoundedRectangle(cornerRadius: 16).fill(Theme.background)
        } else if #available(macOS 26.0, *) {
            Color.black.opacity(0.07)
                .glassEffect(Glass.regular, in: .rect(cornerRadius: 16))
        } else {
            VisualEffectBackground()
                .overlay(Color.black.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Circle().fill(vm.statusColor).frame(width: 8, height: 8)
            Text("Redline")
                .font(Theme.pixelTitle(16))
                .foregroundStyle(Theme.text)
            Spacer()
            iconButton(showSettings ? "chevron.left" : "gearshape") {
                withAnimation(.easeInOut(duration: 0.15)) { showSettings.toggle() }
            }
            iconButton("arrow.clockwise") { Task { await vm.refresh() } }
                .opacity(vm.isRefreshing ? 0.4 : 1)
                .disabled(vm.isRefreshing)
        }
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.label)
                .frame(width: 26, height: 24)
                .glassButton(cornerRadius: 7)
        }
        .buttonStyle(.plain)
    }

    // MARK: Claude

    @ViewBuilder
    private var claudeSection: some View {
        if let usage = vm.usage {
            VStack(spacing: 12) {
                if let w = usage.fiveHour {
                    GaugeRing(percent: w.utilization, caption: "5-HOUR WINDOW")
                        .padding(.top, 2)
                    if let reset = Format.relativeReset(w.resetsAt) {
                        Label(reset, systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.label)
                    }
                }

                let secondary = Array(usage.secondaryWindows.prefix(2))
                if !secondary.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(secondary, id: \.key) { item in
                            MetricCard(systemIcon: Format.windowIcon(item.key),
                                       title: Format.windowLabel(item.key),
                                       percent: item.window.utilization,
                                       caption: Format.relativeReset(item.window.resetsAt))
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .glassGroup()
                }

                if let pace = claudePace(usage) {
                    PaceCard(pace: pace, series: vm.sparkline)
                }
            }
        } else if let err = vm.errorMessage {
            errorView(err)
        } else {
            loading
        }
    }

    private func claudePace(_ usage: OAuthUsage) -> Pace? {
        Pace.evaluate(
            burn: vm.burnRate,
            currentPercent: usage.fiveHour?.utilization ?? 0,
            resetsAt: usage.fiveHour?.resetsAt
        )
    }

    // MARK: Codex

    @ViewBuilder
    private var codexSection: some View {
        if let codex = vm.codex {
            VStack(spacing: 12) {
                if let p = codex.primary {
                    GaugeRing(percent: p.usedPercent, caption: "5-HOUR WINDOW")
                        .padding(.top, 2)
                    if let reset = Format.relativeReset(p.resetsAt) {
                        Label(reset, systemImage: "clock")
                            .font(.system(size: 11)).foregroundStyle(Theme.label)
                    }
                }
                if let s = codex.secondary {
                    MetricCard(systemIcon: "calendar", title: "WEEKLY",
                               percent: s.usedPercent, caption: Format.relativeReset(s.resetsAt))
                }
                if let observed = codex.observedAt {
                    Text("From latest Codex session · \(observed.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10)).foregroundStyle(Theme.subtle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("No Codex sessions found", systemImage: "terminal")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text)
                Text("Run the Codex CLI once so it writes rate-limit data to ~/.codex/sessions.")
                    .font(.system(size: 11)).foregroundStyle(Theme.subtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 20)
        }
    }

    // MARK: Today (local transcripts)

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TODAY'S LOCAL USAGE")
                    .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                    .foregroundStyle(Theme.label)
                Spacer()
                Text(Format.usd(vm.today.totalCost))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.green)
            }

            HStack(spacing: 6) {
                StatPill(label: "in", value: Format.tokens(vm.today.inputTokens))
                StatPill(label: "out", value: Format.tokens(vm.today.outputTokens))
                StatPill(label: "cache rd", value: Format.tokens(vm.today.cacheReadTokens))
                StatPill(label: "msgs", value: "\(vm.today.messages)")
            }
            .fixedSize(horizontal: false, vertical: true)
            .glassGroup()

            if vm.today.perModel.isEmpty {
                Text("No Claude Code activity yet today.")
                    .font(.system(size: 11)).foregroundStyle(Theme.subtle)
            } else {
                ForEach(vm.today.perModel.prefix(4)) { m in
                    HStack {
                        Text(Pricing.displayName(for: m.model))
                            .font(.system(size: 11)).foregroundStyle(Theme.text)
                        Spacer()
                        Text("\(Format.tokens(m.inputTokens + m.outputTokens)) · \(Format.usd(m.cost))")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Theme.subtle)
                    }
                }
            }
        }
    }

    private var loading: some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Loading usage…").font(.system(size: 12)).foregroundStyle(Theme.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Couldn't load usage", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.amber)

            Text(message).font(.system(size: 11)).foregroundStyle(Theme.text)

            if let fix = vm.errorFix {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOW TO FIX")
                        .font(.system(size: 9, weight: .semibold)).tracking(0.5)
                        .foregroundStyle(Theme.label)
                    fixText(fix)
                        .font(.system(size: 11)).foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .glassCard(cornerRadius: 10)
            }

            Button {
                Task { await vm.refresh() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .semibold))
                    Text("Try again").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.12))
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1)))
            }
            .buttonStyle(.plain)
            .disabled(vm.isRefreshing)
            .opacity(vm.isRefreshing ? 0.5 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    /// Renders the fix hint, styling any `backtick` command in monospace.
    private func fixText(_ s: String) -> Text {
        s.split(separator: "`", omittingEmptySubsequences: false).enumerated().reduce(Text("")) { acc, pair in
            let (i, part) = pair
            let chunk = i % 2 == 1
                ? Text(String(part)).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(Theme.amber)
                : Text(String(part))
            return acc + chunk
        }
    }

    private var footer: some View {
        HStack {
            if let updated = vm.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10)).foregroundStyle(Theme.subtle)
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.label)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var vm: UsageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SETTINGS")
                .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                .foregroundStyle(Theme.label)

            VStack(alignment: .leading, spacing: 4) {
                Text("Provider").font(.system(size: 12)).foregroundStyle(Theme.text)
                // Both providers' data is already loaded; switching only changes
                // which section renders — no re-fetch, so it stays instant.
                GlassSegmented(
                    options: Provider.allCases.map { ($0, $0.rawValue) },
                    selection: Binding(get: { vm.provider },
                                       set: { vm.provider = $0; vm.publishSnapshot() })
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Alert threshold: \(Int(vm.alertThreshold))%")
                    .font(.system(size: 12)).foregroundStyle(Theme.text)
                Slider(value: $vm.alertThreshold, in: 50...99, step: 5)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Refresh every \(Int(vm.refreshSeconds))s")
                    .font(.system(size: 12)).foregroundStyle(Theme.text)
                Slider(value: $vm.refreshSeconds, in: 30...300, step: 15) { editing in
                    if !editing { vm.scheduleTimer() }
                }
            }

            Toggle("Launch at login", isOn: Binding(
                get: { LaunchAtLogin.isEnabled },
                set: { LaunchAtLogin.isEnabled = $0 }
            ))
            .font(.system(size: 12))
            .foregroundStyle(Theme.text)
            .toggleStyle(.switch)

            Divider().overlay(Theme.track)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Floating panel", isOn: Binding(
                    get: { vm.showWidget },
                    set: { vm.toggleWidget($0) }
                ))
                .font(.system(size: 12))
                .foregroundStyle(Theme.text)
                .toggleStyle(.switch)

                Text("An always-on-top panel pinned over your screen. For the desktop/Notification Center widget, add “Redline” from the system widget gallery.")
                    .font(.system(size: 10)).foregroundStyle(Theme.subtle)
            }

            if vm.showWidget {
                GlassSegmented(
                    options: WidgetSize.allCases.map { ($0, $0.rawValue) },
                    selection: Binding(get: { vm.widgetSize }, set: { vm.setWidgetSize($0) })
                )
            }

            Text("Claude data comes from your Claude Code login (read from the macOS keychain) and local transcripts. Codex data is read from ~/.codex session logs. Nothing is sent anywhere.")
                .font(.system(size: 10)).foregroundStyle(Theme.subtle)

            Divider().overlay(Theme.track)

            Button {
                NSWorkspace.shared.open(Links.buyMeACoffee)
            } label: {
                HStack(spacing: 6) {
                    Text("☕").font(.system(size: 12))
                    Text("Buy me a coffee").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Capsule().fill(Theme.amber.opacity(0.22))
                    .overlay(Capsule().stroke(Theme.amber.opacity(0.4), lineWidth: 1)))
            }
            .buttonStyle(.plain)
        }
    }
}
