import Foundation
import LumiKernel
import os
import SuperLogKit

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
    /// 后续 status 会覆盖它，AgentTurn 结束时统一清除。不发送 messageSaved 通知。
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
