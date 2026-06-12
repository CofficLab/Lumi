import Foundation

extension Notification.Name {
    static let checkForUpdates = Notification.Name("checkForUpdates")
    static let appUpdateReadyToInstall = Notification.Name("appUpdateReadyToInstall")
    static let installPreparedAppUpdate = Notification.Name("installPreparedAppUpdate")
}

extension NotificationCenter {
    static func postCheckForUpdates() {
        NotificationCenter.default.post(name: .checkForUpdates, object: nil)
    }

    static func postAppUpdateReadyToInstall(version: String) {
        NotificationCenter.default.post(
            name: .appUpdateReadyToInstall,
            object: nil,
            userInfo: ["version": version]
        )
    }

    static func postInstallPreparedAppUpdate() {
        NotificationCenter.default.post(name: .installPreparedAppUpdate, object: nil)
    }
}
