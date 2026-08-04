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
        kernel?.eventManager.postTurnStarted(
            conversationID: conversationID,
            turnID: turnID,
            parentConversationID: parentConversationID
        )
    }

    func postMessageSavedNotification(message: LumiChatMessage, conversationID: UUID) {
        kernel?.eventManager.postMessageSaved(
            messageID: message.id,
            conversationID: conversationID,
            role: message.role.rawValue
        )
    }

    func postTurnCompletedNotification(conversationID: UUID) async {
        guard let turnID = turnIDs[conversationID] else { return }
        kernel?.eventManager.postTurnCompleted(
            conversationID: conversationID,
            turnID: turnID
        )
        // 复用 finished 路径：发送 .lumiTurnFinished 并分发 onTurnFinished 钩子
        await postTurnFinishedNotification(conversationID: conversationID, reason: .completed)
    }

    func postTurnFinishedNotification(conversationID: UUID, reason: LumiTurnEndReason) async {
        kernel?.eventManager.postTurnFinished(
            conversationID: conversationID,
            turnID: turnIDs[conversationID],
            reason: reason,
            parentConversationID: parentConversationIDs[conversationID]
        )

        // 分发 onTurnFinished 钩子（按插件 order 升序，仅启用插件）。
        // 与上面 willSendToLLM 的遍历模式一致。
        guard let kernel else { return }
        for plugin in kernel.pluginManager.allPlugins {
            guard plugin.policy.shouldRegister else { continue }
            await plugin.onTurnFinished(kernel: kernel, conversationID: conversationID, reason: reason)
        }
    }
}
