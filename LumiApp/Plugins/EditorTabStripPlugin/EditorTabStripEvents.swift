import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    /// 当前文件已更新的通知
    /// object: nil
    /// userInfo: ["path": String]
    static let currentFileDidChange = Notification.Name("CurrentFileDidChange")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送当前文件已更新的通知
    static func postCurrentFileDidChange(path: String) {
        NotificationCenter.default.post(
            name: .currentFileDidChange,
            object: nil,
            userInfo: ["path": path]
        )
    }
}

// MARK: - View Extension

extension View {
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
