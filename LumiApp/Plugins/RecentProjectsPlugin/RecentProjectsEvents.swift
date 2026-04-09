import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    /// 当前项目已更新的通知
    /// object: nil
    /// userInfo: ["projectName": String, "projectPath": String]
    static let currentProjectDidChange = Notification.Name("CurrentProjectDidChange")
    
    /// 当前文件已更新的通知
    /// object: nil
    /// userInfo: ["path": String]
    static let currentFileDidChange = Notification.Name("CurrentFileDidChange")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送当前项目已更新的通知
    static func postCurrentProjectDidChange(name: String, path: String) {
        NotificationCenter.default.post(
            name: .currentProjectDidChange,
            object: nil,
            userInfo: ["projectName": name, "projectPath": path]
        )
    }
    
    /// 发送当前文件已更新的通知
    static func postCurrentFileDidChange(path: String) {
        NotificationCenter.default.post(
            name: .currentFileDidChange,
            object: nil,
            userInfo: ["path": path]
        )
    }
}

// MARK: - View Extensions for Project Events

extension View {
    /// 监听当前项目变化的事件
    /// - Parameter action: 事件处理闭包，接收项目名称和路径
    /// - Returns: 修改后的视图
    func onCurrentProjectDidChange(perform action: @escaping (String, String) -> Void) -> some View {
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
    
    /// 监听当前文件变化的事件
    /// - Parameter action: 事件处理闭包，接收文件路径
    /// - Returns: 修改后的视图
    func onCurrentFileDidChange(perform action: @escaping (String) -> Void) -> some View {
        self.onReceive(
            NotificationCenter.default
                .publisher(for: .currentFileDidChange)
                .receive(on: RunLoop.main)
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let path = userInfo["path"] as? String else {
                return
            }
            action(path)
        }
    }
}