import SwiftUI
import AppKit

enum WidgetSize: String, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    var id: String { rawValue }
}

/// The visual content of the floating desktop widget.
struct DesktopWidgetView: View {
    @ObservedObject var vm: UsageViewModel
    let size: WidgetSize

    var body: some View {
        VStack(spacing: 10) {
            Group {
                switch size {
                case .small: small
                case .medium: medium
                }
            }
            refreshButton
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        // Transparent breathing room so the rounded card's shadow isn't clipped
        // by the (rectangular) window edge — which otherwise shows as a faint
        // frame in the corners.
        .padding(16)
        .fixedSize()
        .preferredColorScheme(.dark)
    }

    private var fiveHour: Double {
        switch vm.provider {
        case .claude: return vm.usage?.fiveHour?.utilization ?? 0
        case .codex: return vm.codex?.primary?.usedPercent ?? 0
        }
    }
    private var weekly: Double {
        switch vm.provider {
        case .claude: return vm.usage?.sevenDay?.utilization ?? 0
        case .codex: return vm.codex?.secondary?.usedPercent ?? 0
        }
    }
    private var fiveHourReset: String? {
        switch vm.provider {
        case .claude: return Format.relativeReset(vm.usage?.fiveHour?.resetsAt)
        case .codex: return Format.relativeReset(vm.codex?.primary?.resetsAt)
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await vm.refresh() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                Text("Refresh")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color.white.opacity(0.12))
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .opacity(vm.isRefreshing ? 0.45 : 1)
        .disabled(vm.isRefreshing)
        .help("Refresh")
    }

    private var small: some View {
        VStack(spacing: 6) {
            GaugeRing(percent: fiveHour, caption: "5-HOUR", size: 96, lineWidth: 10)
            if let r = fiveHourReset {
                Text(r).font(.system(size: 9)).foregroundStyle(Theme.subtle)
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 18) {
            VStack(spacing: 4) {
                GaugeRing(percent: fiveHour, caption: "5-HOUR", size: 92, lineWidth: 10)
                if let r = fiveHourReset {
                    Text(r).font(.system(size: 9)).foregroundStyle(Theme.subtle)
                }
            }
            VStack(spacing: 4) {
                GaugeRing(percent: weekly, caption: "WEEKLY", size: 92, lineWidth: 10)
                Text(vm.provider.rawValue).font(.system(size: 9)).foregroundStyle(Theme.subtle)
            }
        }
    }
}

/// Hosts the widget in a borderless panel pinned just above the desktop, so it
/// "lives on your desktop" like the App Store widgets. Draggable; position is
/// remembered.
@MainActor
final class DesktopWidgetController {
    private var panel: NSPanel?
    private let vm: UsageViewModel

    init(vm: UsageViewModel) { self.vm = vm }

    func setVisible(_ visible: Bool, size: WidgetSize) {
        if visible { show(size: size) } else { hide() }
    }

    func updateSize(_ size: WidgetSize) {
        guard panel != nil else { return }
        show(size: size)
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func show(size: WidgetSize) {
        hide()

        // Size the window to the content's natural size so the rounded glass
        // card + its shadow are fully contained and the corners stay clean.
        let host = NSHostingView(rootView: DesktopWidgetView(vm: vm, size: size))
        host.layoutSubtreeIfNeeded()
        var dimensions = host.fittingSize
        if dimensions.width < 40 || dimensions.height < 40 {
            dimensions = size == .small ? NSSize(width: 182, height: 237)
                                        : NSSize(width: 312, height: 217)
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: savedOrigin(default: defaultOrigin(for: dimensions)), size: dimensions),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        // Float above normal windows so the widget is always visible (and
        // draggable). A desktop-level panel would sit behind every window.
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false

        host.frame = NSRect(origin: .zero, size: dimensions)
        panel.contentView = host

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak panel] _ in
            guard let panel else { return }
            UserDefaults.standard.set(
                NSStringFromPoint(panel.frame.origin), forKey: "widgetOrigin")
        }

        panel.orderFront(nil)
        self.panel = panel
    }

    private func defaultOrigin(for size: NSSize) -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return NSPoint(x: 80, y: 80) }
        return NSPoint(x: frame.maxX - size.width - 40,
                       y: frame.maxY - size.height - 40)
    }

    private func savedOrigin(default fallback: NSPoint) -> NSPoint {
        guard let s = UserDefaults.standard.string(forKey: "widgetOrigin") else { return fallback }
        let p = NSPointFromString(s)
        if p == .zero { return fallback }
        // Only restore a saved position if it still lands on a connected screen;
        // a stale off-screen origin (display reconfig) would hide the widget.
        let rect = NSRect(origin: p, size: NSSize(width: 60, height: 40))
        let onScreen = NSScreen.screens.contains { $0.frame.intersects(rect) }
        return onScreen ? p : fallback
    }
}
