import Foundation

extension Notification.Name {
    static let appUpdateReadyToInstall = Notification.Name("appUpdateReadyToInstall")
    static let installPreparedAppUpdate = Notification.Name("installPreparedAppUpdate")
}

extension NotificationCenter {
    static func postInstallPreparedAppUpdate() {
        NotificationCenter.default.post(name: .installPreparedAppUpdate, object: nil)
    }
}
