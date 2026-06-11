import Foundation

/// Listens for the Darwin notification the widget's refresh button posts, and
/// runs the app's refresh. Cross-process and sandbox-safe (Darwin notifications
/// carry no payload and need no entitlement).
enum RefreshBridge {
    static var onRefresh: (() -> Void)?
    private static var started = false

    static func start() {
        guard !started else { return }
        started = true
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async { RefreshBridge.onRefresh?() }
            },
            redlineRefreshNotification as CFString,
            nil,
            .deliverImmediately
        )
    }
}
