import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    /// 后台任务已创建的通知
    /// object: nil
    /// userInfo: ["taskId": UUID as String]
    static let backgroundAgentTaskDidCreate = Notification.Name("backgroundAgentTaskDidCreate")

    /// 后台任务状态已更新的通知
    /// object: nil
    /// userInfo: ["taskId": UUID as String, "status": String]
    static let backgroundAgentTaskDidUpdate = Notification.Name("backgroundAgentTaskDidUpdate")
}

// MARK: - NotificationCenter Extensions

extension NotificationCenter {
    /// 发送后台任务已创建的通知
    /// - Parameter taskId: 任务 ID
    static func postBackgroundAgentTaskDidCreate(taskId: UUID) {
        NotificationCenter.default.post(
            name: .backgroundAgentTaskDidCreate,
            object: nil,
            userInfo: ["taskId": taskId.uuidString]
        )
    }

    /// 发送后台任务状态已更新的通知
    /// - Parameters:
    ///   - taskId: 任务 ID
    ///   - status: 新状态
    static func postBackgroundAgentTaskDidUpdate(taskId: UUID, status: String) {
        NotificationCenter.default.post(
            name: .backgroundAgentTaskDidUpdate,
            object: nil,
            userInfo: [
                "taskId": taskId.uuidString,
                "status": status
            ]
        )
    }
}

// MARK: - View Extensions

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

    /// 监听后台任务状态更新的事件
    /// - Parameter action: 事件处理闭包，接收任务 ID 和状态
    /// - Returns: 修改后的视图
    func onBackgroundAgentTaskDidUpdate(perform action: @escaping (UUID, String) -> Void) -> some View {
        self.onReceive(
            NotificationCenter.default
                .publisher(for: .backgroundAgentTaskDidUpdate)
                .receive(on: RunLoop.main)
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let taskIdString = userInfo["taskId"] as? String,
                  let taskId = UUID(uuidString: taskIdString),
                  let status = userInfo["status"] as? String else {
                return
            }
            action(taskId, status)
        }
    }
}
