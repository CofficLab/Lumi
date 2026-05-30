import Foundation

extension Notification.Name {
    static let appUpdateReadyToInstall = Notification.Name("appUpdateReadyToInstall")
    static let installPreparedAppUpdate = Notification.Name("installPreparedAppUpdate")
    static let requestMenuBarAppearanceUpdate = Notification.Name("requestMenuBarAppearanceUpdate")
}

extension NotificationCenter {
    static func postRequestMenuBarAppearanceUpdate(isActive: Bool, source: String) {
        NotificationCenter.default.post(
            name: .requestMenuBarAppearanceUpdate,
            object: nil,
            userInfo: [
                "isActive": isActive,
                "source": source,
            ]
        )
    }

    static func postInstallPreparedAppUpdate() {
        NotificationCenter.default.post(name: .installPreparedAppUpdate, object: nil)
    }
}
