import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    /// 对话选择的通知
    /// object: UUID (对话 ID)
    static let conversationSelected = Notification.Name("conversationSelected")

    /// Agent 模式：新对话被创建的通知
    /// object: UUID (对话 ID)
    static let agentConversationCreated = Notification.Name("agentConversationCreated")

    /// 工具授权流程结束（全部非 pending），应继续 `SendController.resumeAfterPermissionGranted(conversationId:)` 管线
    /// object: UUID (对话 ID)
    static let resumeSendAfterToolPermission = Notification.Name("resumeSendAfterToolPermission")

    /// Agent 模式：某对话一轮发送/处理已完成（`SendController.finishSendTurn`）
    /// object: UUID (对话 ID)
    static let agentConversationSendTurnFinished = Notification.Name("agentConversationSendTurnFinished")
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

    /// 发送 Agent 模式：新对话被创建的通知
    /// - Parameter conversationId: 对话 ID
    static func postAgentConversationCreated(conversationId: UUID) {
        NotificationCenter.default.post(
            name: .agentConversationCreated,
            object: conversationId
        )
    }

    /// 工具授权已处理完毕，继续发送管线
    static func postResumeSendAfterToolPermission(conversationId: UUID) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .resumeSendAfterToolPermission,
                object: conversationId
            )
        }
    }

    /// 某对话一轮发送/处理已完成
    static func postAgentConversationSendTurnFinished(conversationId: UUID) {
        NotificationCenter.default.post(
            name: .agentConversationSendTurnFinished,
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

    /// 监听 Agent 模式：新对话被创建的事件
    /// - Parameter action: 事件处理闭包，参数为对话 ID
    /// - Returns: 修改后的视图
    func onAgentConversationCreated(perform action: @escaping (UUID) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .agentConversationCreated)) { notification in
            if let conversationId = notification.object as? UUID {
                action(conversationId)
            }
        }
    }

    /// 工具授权完成后继续发送管线
    func onResumeSendAfterToolPermission(perform action: @escaping (UUID) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .resumeSendAfterToolPermission)) { notification in
            if let conversationId = notification.object as? UUID {
                action(conversationId)
            }
        }
    }

    /// 监听某对话一轮发送/处理已完成
    func onAgentConversationSendTurnFinished(perform action: @escaping (UUID) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .agentConversationSendTurnFinished)) { notification in
            if let conversationId = notification.object as? UUID {
                action(conversationId)
            }
        }
    }
}
