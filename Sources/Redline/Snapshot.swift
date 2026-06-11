import SwiftUI
import AppKit

/// Dev-only: renders the popup with mock data to a PNG so the layout can be
/// reviewed without clicking the live menu-bar item. Triggered by CMETER_SNAPSHOT.
@MainActor
enum Snapshot {
    static func renderAndExit() {
        GlassEnv.forceSolid = true
        let vm = UsageViewModel.mock()
        let view = MenuContentView(vm: vm)
            .frame(width: 320)
            .fixedSize(horizontal: false, vertical: true)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        write(renderer.nsImage, to: "preview.png")

        // Error-state preview.
        let errVM = UsageViewModel.mockError()
        let errView = MenuContentView(vm: errVM)
            .frame(width: 320).fixedSize(horizontal: false, vertical: true)
        let er = ImageRenderer(content: errView); er.scale = 2
        write(er.nsImage, to: "error_preview.png")

        exit(0)
    }

    private static func write(_ image: NSImage?, to name: String) {
        guard let image,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        let url = URL(fileURLWithPath: "/tmp/redline-shots/\(name)")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? png.write(to: url)
        FileHandle.standardError.write("wrote \(url.path)\n".data(using: .utf8)!)
    }
}

extension UsageViewModel {
    static func mock() -> UsageViewModel {
        let vm = UsageViewModel()
        let now = Date()
        vm.usage = OAuthUsage(windows: [
            "five_hour": UsageWindow(utilization: 42, resetsAt: now.addingTimeInterval(2 * 3600 + 29 * 60)),
            "seven_day": UsageWindow(utilization: 31, resetsAt: now.addingTimeInterval(4 * 86400)),
            "seven_day_sonnet": UsageWindow(utilization: 28, resetsAt: now.addingTimeInterval(4 * 86400)),
        ])
        vm.sparkline = [10, 12, 14, 13, 18, 22, 26, 30, 33, 38, 40, 41, 42]
        vm.burnRate = BurnRate(percentPerHour: 5.2, projectedExhaustion: now.addingTimeInterval(11 * 3600))
        vm.today = {
            var d = DayStats()
            d.totalCost = 6.84
            d.inputTokens = 184_000; d.outputTokens = 92_000; d.cacheReadTokens = 2_300_000; d.messages = 148
            d.perModel = [
                ModelStats(model: "claude-opus-4-8", inputTokens: 120_000, outputTokens: 60_000, cost: 4.9, messages: 90),
                ModelStats(model: "claude-sonnet-4-6", inputTokens: 64_000, outputTokens: 32_000, cost: 1.94, messages: 58),
            ]
            return d
        }()
        vm.lastUpdated = now
        return vm
    }

    static func mockError() -> UsageViewModel {
        let vm = UsageViewModel()
        vm.usage = nil
        vm.errorMessage = "Your Claude session has expired."
        vm.errorFix = "Open Terminal and run `claude` then `/login` to re-authenticate. Then tap Try again."
        vm.lastUpdated = Date()
        return vm
    }
}
