import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    /// 当前项目已更新的通知
    /// object: nil
    /// userInfo: ["projectName": String, "projectPath": String]
    public static let currentProjectDidChange = Notification.Name("CurrentProjectDidChange")
    public static let projectsListDidChange = Notification.Name("ProjectsListDidChange")
    public static let applicationDidBecomeActive = Notification.Name("applicationDidBecomeActive")
    public static let windowStateShouldPersist = Notification.Name("windowStateShouldPersist")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送当前项目已更新的通知
    public static func postCurrentProjectDidChange(name: String, path: String) {
        NotificationCenter.default.post(
            name: .currentProjectDidChange,
            object: nil,
            userInfo: ["projectName": name, "projectPath": path]
        )
    }
}

// MARK: - View Extensions for Project Events

extension View {
    /// 监听当前项目变化的事件
    /// - Parameter action: 事件处理闭包，接收项目名称和路径
    /// - Returns: 修改后的视图
    public func onCurrentProjectDidChange(perform action: @escaping (String, String) -> Void) -> some View {
        self.onReceive(
            NotificationCenter.default
                .publisher(for: .currentProjectDidChange)
                .receive(on: RunLoop.main)
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let name = userInfo["projectName"] as? String,
                  let path = userInfo["projectPath"] as? String else {
                return
            }
            action(name, path)
        }
    }

    public func onApplicationDidBecomeActive(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationDidBecomeActive)) { _ in
            action()
        }
    }
}
