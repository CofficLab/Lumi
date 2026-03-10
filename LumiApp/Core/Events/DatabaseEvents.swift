import SwiftUI
import SwiftData

// MARK: - Notification Extension

extension Notification.Name {
    /// 消息已保存到数据库的通知
    /// object: ChatMessage (消息对象)
    static let messageSaved = Notification.Name("messageSaved")

    /// 对话已创建的通知
    /// object: UUID (对话 ID)
    static let conversationCreated = Notification.Name("conversationCreated")

    /// 对话已更新的通知
    /// object: UUID (对话 ID)
    static let conversationUpdated = Notification.Name("conversationUpdated")

    /// 对话已删除的通知
    /// object: UUID (对话 ID)
    static let conversationDeleted = Notification.Name("conversationDeleted")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送消息已保存到数据库的通知
    /// 自动在主线程发送通知
    /// - Parameter message: 消息对象
    static func postMessageSaved(message: ChatMessage) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .messageSaved,
                object: message
            )
        }
    }

    /// 发送对话已创建的通知
    /// 自动在主线程发送通知
    /// - Parameter conversationId: 对话 ID
    static func postConversationCreated(conversationId: UUID) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .conversationCreated,
                object: conversationId
            )
        }
    }

    /// 发送对话已更新的通知
    /// 自动在主线程发送通知
    /// - Parameter conversationId: 对话 ID
    static func postConversationUpdated(conversationId: UUID) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .conversationUpdated,
                object: conversationId
            )
        }
    }

    /// 发送对话已删除的通知
    /// 自动在主线程发送通知
    /// - Parameter conversationId: 对话 ID
    static func postConversationDeleted(conversationId: UUID) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .conversationDeleted,
                object: conversationId
            )
        }
    }
}

// MARK: - View Extensions for Database Events

extension View {
    /// 监听消息已保存到数据库的事件
    /// - Parameter action: 事件处理闭包，参数为消息对象
    /// - Returns: 修改后的视图
    func onMessageSaved(perform action: @escaping (ChatMessage) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .messageSaved)) { notification in
            if let message = notification.object as? ChatMessage {
                action(message)
            }
        }
    }

    /// 监听对话已创建的事件
    /// - Parameter action: 事件处理闭包，参数为对话 ID
    /// - Returns: 修改后的视图
    func onConversationCreated(perform action: @escaping (UUID) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .conversationCreated)) { notification in
            if let conversationId = notification.object as? UUID {
                action(conversationId)
            }
        }
    }

    /// 监听对话已更新的事件
    /// - Parameter action: 事件处理闭包，参数为对话 ID
    /// - Returns: 修改后的视图
    func onConversationUpdated(perform action: @escaping (UUID) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .conversationUpdated)) { notification in
            if let conversationId = notification.object as? UUID {
                action(conversationId)
            }
        }
    }

    /// 监听对话已删除的事件
    /// - Parameter action: 事件处理闭包，参数为对话 ID
    /// - Returns: 修改后的视图
    func onConversationDeleted(perform action: @escaping (UUID) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .conversationDeleted)) { notification in
            if let conversationId = notification.object as? UUID {
                action(conversationId)
            }
        }
    }
}
