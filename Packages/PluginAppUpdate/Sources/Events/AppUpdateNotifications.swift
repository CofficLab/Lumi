import Foundation

/// App update notification names and posting helpers.
///
/// Ported from `LumiAppKit/Events/AppUpdateNotifications.swift` (v4.19.0).
/// The public API (`Notification.Name` extensions and `NotificationCenter`
/// static helpers) is intentionally kept identical so that call sites in
/// `MacAgent`, `MenuBarManagerPlugin` and the About settings page can
/// communicate with `UpdateService` without a hard dependency on the plugin.
public extension Notification.Name {
    /// Triggers a "check for updates" request; observed by `UpdateService`.
    static let checkForUpdates = Notification.Name("checkForUpdates")

    /// A downloaded update is ready to be installed on quit.
    /// `userInfo["version"]` carries the displayable version string.
    static let appUpdateReadyToInstall = Notification.Name("appUpdateReadyToInstall")

    /// Requests immediate installation of a previously prepared update.
    static let installPreparedAppUpdate = Notification.Name("installPreparedAppUpdate")
}

/// Convenience static methods for posting app-update notifications.
public extension NotificationCenter {
    /// Post a "check for updates" request.
    static func postCheckForUpdates() {
        NotificationCenter.default.post(name: .checkForUpdates, object: nil)
    }

    /// Post a "downloaded update ready to install on quit" notification.
    /// - Parameter version: `SUAppcastItem.displayVersionString` from Sparkle.
    static func postAppUpdateReadyToInstall(version: String) {
        NotificationCenter.default.post(
            name: .appUpdateReadyToInstall,
            object: nil,
            userInfo: ["version": version]
        )
    }

    /// Post an "install prepared update immediately" request.
    static func postInstallPreparedAppUpdate() {
        NotificationCenter.default.post(name: .installPreparedAppUpdate, object: nil)
    }
}
