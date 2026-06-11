import AppIntents
import WidgetKit
import Foundation

/// Darwin notification name the widget posts and the app listens for.
let redlineRefreshNotification = "net.alienminds.redline.refresh"

/// Backs the widget's refresh button. The widget extension is sandboxed and
/// can't fetch usage itself, so this just nudges the (always-running) menu-bar
/// app to refresh; the app then rewrites the snapshot and reloads the timeline.
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh usage"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(redlineRefreshNotification as CFString),
            nil, nil, true)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
