import SwiftUI

@main
struct RedlineApp: App {
    @StateObject private var vm = UsageViewModel()

    init() {
        if ProcessInfo.processInfo.environment["CMETER_SNAPSHOT"] != nil {
            Snapshot.renderAndExit()
        }
        Notifier.requestAuthorization()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(vm: vm)
        } label: {
            MenuBarLabel(vm: vm)
                // The label is present from launch, so its task starts the
                // refresh loop and desktop widget immediately — not only after
                // the user first opens the popover.
                .task { vm.start() }
        }
        .menuBarExtraStyle(.window)
    }
}

/// The compact menu-bar label: a colored ring/percentage that reflects the
/// most-constrained limit for the selected provider.
struct MenuBarLabel: View {
    @ObservedObject var vm: UsageViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: gaugeSymbol)
                .foregroundStyle(vm.statusColor)
            Text(Format.percent(vm.headlinePercent))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    private var gaugeSymbol: String {
        let p = vm.headlinePercent
        if p >= 90 { return "gauge.with.dots.needle.100percent" }
        if p >= 60 { return "gauge.with.dots.needle.67percent" }
        if p >= 30 { return "gauge.with.dots.needle.33percent" }
        return "gauge.with.dots.needle.0percent"
    }
}
