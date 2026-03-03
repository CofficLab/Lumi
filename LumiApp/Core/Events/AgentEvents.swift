import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    /// 对话选择的通知
    /// object: UUID (对话 ID)
    static let conversationSelected = Notification.Name("conversationSelected")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送对话选择的通知
    /// - Parameter conversationId: 对话 ID
    static func postConversationSelected(conversationId: UUID) {
        NotificationCenter.default.post(
            name: .conversationSelected,
            object: conversationId
        )
    }
}

// MARK: - View Extensions for Agent Events

extension View {
    /// 监听对话选择的事件
    /// - Parameter action: 事件处理闭包，参数为对话 ID
    /// - Returns: 修改后的视图
    func onConversationSelected(perform action: @escaping (UUID) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .conversationSelected)) { notification in
            if let conversationId = notification.object as? UUID {
                action(conversationId)
            }
        }
    }
}
