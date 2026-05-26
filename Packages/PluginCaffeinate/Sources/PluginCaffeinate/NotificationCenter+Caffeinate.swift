import Foundation

extension Notification.Name {
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
}
