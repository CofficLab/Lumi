import Foundation

/// App 更新相关的通知名称与发布辅助方法
///
/// 从 `LumiApp/Events/AppUpdateNotifications.swift` 复刻而来，
/// 公共 API（`Notification.Name` 扩展、`NotificationCenter` 静态方法）保持完全一致。
public extension Notification.Name {
    /// 触发"检查更新"请求的通知，由 `UpdateService` 监听。
    static let checkForUpdates = Notification.Name("checkForUpdates")

    /// 通知"有可用更新已下载，待退出时安装"。
    /// `userInfo["version"]` 携带可显示的版本号字符串。
    static let appUpdateReadyToInstall = Notification.Name("appUpdateReadyToInstall")

    /// 通知"立即安装已准备好的更新"。
    static let installPreparedAppUpdate = Notification.Name("installPreparedAppUpdate")
}

/// 便捷发送 App 更新相关通知的静态方法
public extension NotificationCenter {
    /// 发送"检查更新"请求
    static func postCheckForUpdates() {
        NotificationCenter.default.post(name: .checkForUpdates, object: nil)
    }

    /// 发送"有可用更新已下载，待退出时安装"通知
    /// - Parameter version: Sparkle 返回的 `SUAppcastItem.displayVersionString`。
    static func postAppUpdateReadyToInstall(version: String) {
        NotificationCenter.default.post(
            name: .appUpdateReadyToInstall,
            object: nil,
            userInfo: ["version": version]
        )
    }

    /// 发送"立即安装已准备好的更新"通知
    static func postInstallPreparedAppUpdate() {
        NotificationCenter.default.post(name: .installPreparedAppUpdate, object: nil)
    }
}