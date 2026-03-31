import Foundation
import SwiftData

// MARK: - 存储操作扩展

extension ChatHistoryService {

    /// 保存或更新对话
    func saveConversation(_ conversation: Conversation) {
        let context = self.getContext()
        context.insert(conversation)

        do {
            try context.save()
        } catch {
            AppLogger.core.error("\(Self.t)❌ 保存对话失败：\(error.localizedDescription)")
        }
    }

    func notifyConversationChanged(type: ConversationChangeType, conversationId: UUID) {
        let userInfo: [String: String] = [
            ConversationChangeUserInfoKey.type: type.rawValue,
            ConversationChangeUserInfoKey.conversationId: conversationId.uuidString,
        ]

        let postOnCurrentThread = {
            NotificationCenter.default.post(
                name: .conversationDidChange,
                object: nil,
                userInfo: userInfo
            )
        }

        if Thread.isMainThread {
            postOnCurrentThread()
        } else {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .conversationDidChange,
                    object: nil,
                    userInfo: userInfo
                )
            }
        }
    }

    /// 删除对话
    func deleteConversation(_ conversation: Conversation) {
        let context = self.getContext()
        context.delete(conversation)

        do {
            try context.save()
            notifyConversationChanged(type: .deleted, conversationId: conversation.id)
            NotificationCenter.postConversationDeleted(conversationId: conversation.id)
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🗑️ 对话已删除：\(conversation.title)")
            }
        } catch {
            AppLogger.core.error("\(Self.t)❌ 删除对话失败：\(error.localizedDescription)")
        }
    }
}
