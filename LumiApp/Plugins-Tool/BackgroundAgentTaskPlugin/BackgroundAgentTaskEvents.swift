import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    /// 后台任务已创建的通知
    /// object: nil
    /// userInfo: ["taskId": UUID]
    static let backgroundAgentTaskDidCreate = Notification.Name("backgroundAgentTaskDidCreate")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送后台任务已创建的通知
    /// - Parameter taskId: 任务 ID
    static func postBackgroundAgentTaskDidCreate(taskId: UUID) {
        NotificationCenter.default.post(
            name: .backgroundAgentTaskDidCreate,
            object: nil,
            userInfo: ["taskId": taskId]
        )
    }
}

// MARK: - View Extensions for Background Task Events

extension View {
    /// 监听后台任务创建的事件
    /// - Parameter action: 事件处理闭包，接收任务 ID
    /// - Returns: 修改后的视图
    func onBackgroundAgentTaskDidCreate(perform action: @escaping (UUID) -> Void) -> some View {
        self.onReceive(
            NotificationCenter.default
                .publisher(for: .backgroundAgentTaskDidCreate)
                .receive(on: RunLoop.main)
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let taskIdString = userInfo["taskId"] as? String,
                  let taskId = UUID(uuidString: taskIdString) else {
                return
            }
            action(taskId)
        }
    }
}
