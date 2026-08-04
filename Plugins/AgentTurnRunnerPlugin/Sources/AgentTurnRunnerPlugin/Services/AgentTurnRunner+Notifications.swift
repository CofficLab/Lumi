import Foundation
import LumiKernel
import os
import SuperLogKit

// MARK: - Notifications

extension AgentTurnRunner {

    func postTurnStartedNotification(
        conversationID: UUID,
        turnID: UUID,
        parentConversationID: UUID?
    ) {
        var userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiTurnStartedNotification.turnIDKey: turnID,
        ]
        if let parentConversationID {
            userInfo[LumiTurnStartedNotification.parentConversationIDKey] = parentConversationID
        }
        NotificationCenter.default.post(
            name: .lumiTurnStarted,
            object: nil,
            userInfo: userInfo
        )
    }

    func postMessageSavedNotification(message: LumiChatMessage, conversationID: UUID) {
        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            "messageID": message.id,
            LumiMessageSavedNotification.roleKey: message.role.rawValue,
        ]
        NotificationCenter.default.post(
            name: .lumiMessageSaved,
            object: nil,
            userInfo: userInfo
        )
    }

    func postTurnCompletedNotification(conversationID: UUID) async {
        let userInfo = turnNotificationUserInfo(
            conversationID: conversationID,
            reason: LumiTurnEndReason.completed
        )
        NotificationCenter.default.post(
            name: .lumiTurnCompleted,
            object: nil,
            userInfo: userInfo
        )
        // 复用 finished 路径：发送 .lumiTurnFinished 并分发 onTurnFinished 钩子
        await postTurnFinishedNotification(conversationID: conversationID, reason: .completed)
    }

    func postTurnFinishedNotification(conversationID: UUID, reason: LumiTurnEndReason) async {
        let userInfo = turnNotificationUserInfo(
            conversationID: conversationID,
            reason: reason
        )
        NotificationCenter.default.post(
            name: .lumiTurnFinished,
            object: nil,
            userInfo: userInfo
        )

        // 分发 onTurnFinished 钩子（按插件 order 升序，仅启用插件）。
        // 与上面 willSendToLLM 的遍历模式一致。
        guard let kernel else { return }
        for plugin in kernel.pluginManager.allPlugins {
            guard plugin.policy.shouldRegister else { continue }
            await plugin.onTurnFinished(kernel: kernel, conversationID: conversationID, reason: reason)
        }
    }

    func turnNotificationUserInfo(
        conversationID: UUID,
        reason: LumiTurnEndReason
    ) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiTurnFinishedNotification.reasonKey: reason.rawValue,
        ]
        if let turnID = turnIDs[conversationID] {
            userInfo[LumiTurnFinishedNotification.turnIDKey] = turnID
        }
        if let parentConversationID = parentConversationIDs[conversationID] {
            userInfo[LumiTurnFinishedNotification.parentConversationIDKey] = parentConversationID
        }
        return userInfo
    }
}

// MARK: - Helpers

extension AgentTurnRunner {

    func appendErrorMessage(conversationID: UUID, content: String) {
        guard let kernel else { return }
        let errorMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: content
        )
        kernel.messageManager?.insertMessage(errorMessage, to: conversationID)
        postMessageSavedNotification(message: errorMessage, conversationID: conversationID)
    }

    /// 插入一条瞬时 status 消息(如"正在执行: X…"),由 `MessageManaging` 仅存内存、不落盘。
    /// 工具结果/回合产物 insert 时自动清除。不发送 messageSaved 通知(status 是瞬时的,无需回看)。
    func insertStatusMessage(conversationID: UUID, content: String) {
        guard let kernel else { return }
        let status = LumiChatMessage(
            conversationID: conversationID,
            role: .status,
            content: content,
            metadata: ["isTransientStatus": "true"]
        )
        kernel.messageManager?.insertMessage(status, to: conversationID)
    }

    static func messageMetrics(_ messages: [LumiChatMessage]) -> (
        contentChars: Int,
        metadataChars: Int,
        reasoningChars: Int,
        toolCallArgumentChars: Int
    ) {
        var contentChars = 0
        var metadataChars = 0
        var reasoningChars = 0
        var toolCallArgumentChars = 0

        for message in messages {
            contentChars += message.content.count
            metadataChars += message.metadata.reduce(0) { $0 + $1.key.count + $1.value.count }
            reasoningChars += message.reasoningContent?.count ?? 0
            toolCallArgumentChars += message.toolCalls?.reduce(0) { $0 + $1.arguments.count } ?? 0
        }

        return (contentChars, metadataChars, reasoningChars, toolCallArgumentChars)
    }
}
