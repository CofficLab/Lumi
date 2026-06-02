import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    /// 项目配置已应用的通知
    /// object: ProjectConfig (项目配置)
    static let projectConfigApplied = Notification.Name("ProjectConfigApplied")

    /// 同步选中文件到 WindowProjectVM 的通知
    /// userInfo: ["path": String, "windowId": UUID?]
    static let syncSelectedFile = Notification.Name("SyncSelectedFile")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送项目配置已应用的通知
    /// - Parameter config: 项目配置
    static func postProjectConfigApplied(_ config: ProjectConfig) {
        NotificationCenter.default.post(
            name: .projectConfigApplied,
            object: config
        )
    }

    /// 发送同步选中文件到 WindowProjectVM 的通知
    /// - Parameters:
    ///   - path: 文件路径
    ///   - windowId: 目标窗口 ID，用于多窗口场景下的事件隔离
    static func postSyncSelectedFile(path: String, windowId: UUID? = nil) {
        NotificationCenter.default.post(
            name: .syncSelectedFile,
            object: nil,
            userInfo: [
                "path": path,
                "windowId": windowId as Any,
            ]
        )
    }
}

// MARK: - View Extensions for Project Events

extension View {
    /// 监听项目配置已应用的事件
    /// - Parameter action: 事件处理闭包，参数为项目配置
    /// - Returns: 修改后的视图
    func onProjectConfigApplied(perform action: @escaping (ProjectConfig) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .projectConfigApplied)) { notification in
            if let config = notification.object as? ProjectConfig {
                action(config)
            }
        }
    }

    /// 监听同步选中文件事件
    /// - Parameter action: 事件处理闭包，参数为文件路径
    /// - Returns: 修改后的视图
    func onSyncSelectedFile(
        windowId: UUID? = nil,
        perform action: @escaping (String) -> Void
    ) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .syncSelectedFile)) { notification in
            guard let userInfo = notification.userInfo,
                  let path = userInfo["path"] as? String else {
                return
            }
            if let windowId {
                guard let senderWindowId = userInfo["windowId"] as? UUID,
                      senderWindowId == windowId else {
                    return
                }
            }
            action(path)
        }
    }
}
