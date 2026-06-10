import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    /// 当前文件已更新的通知
    /// object: nil
    /// userInfo: ["path": String]
    public static let currentFileDidChange = Notification.Name("CurrentFileDidChange")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送当前文件已更新的通知
    public static func postCurrentFileDidChange(path: String) {
        NotificationCenter.default.post(
            name: .currentFileDidChange,
            object: nil,
            userInfo: ["path": path]
        )
    }
}

