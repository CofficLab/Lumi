import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// 监听 DB 事件，在首条用户消息落库后于后台独立生成对话标题。
enum TitleOrchestrator: SuperLog {
    nonisolated static let emoji = "✏️"
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-title")

    @MainActor
    static func handleMessageSaved(message: ChatMessage, conversationId: UUID) {
        guard message.role == .user else { return }
        guard !ConversationTitleRuntimeBridge.inFlightConversationIds.contains(conversationId) else {
            if ConversationTitlePlugin.verbose {
                logger.debug("\(Self.t)skip: inFlight")
            }
            return
        }

        if ConversationTitlePlugin.verbose {
            logger.info("\(Self.t)首条用户消息已落库，准备生成标题")
        }

        Task { @MainActor in
            await generateIfNeeded(userMessage: message, conversationId: conversationId)
        }
    }

    @MainActor
    private static func generateIfNeeded(userMessage: ChatMessage, conversationId: UUID) async {
        ConversationTitleRuntimeBridge.inFlightConversationIds.insert(conversationId)
        defer { ConversationTitleRuntimeBridge.inFlightConversationIds.remove(conversationId) }

        let newConversation = String(localized: "New Conversation", bundle: .module)
        let newChat = String(localized: "New Chat", bundle: .module)
        let currentTitle = ConversationTitleRuntimeBridge.fetchConversationTitle(conversationId) ?? ""

        let policy = AutoConversationTitlePolicy()
        let messages = ConversationTitleRuntimeBridge.loadMessages(conversationId)
        let userCount = messages.filter { $0.role == .user }.count

        let evaluation = policy.evaluate(
            AutoConversationTitlePolicy.Input(
                role: userMessage.role,
                userText: userMessage.content,
                currentTitle: currentTitle,
                userMessageCount: userCount,
                newConversationTitle: newConversation,
                newChatTitlePrefix: newChat
            )
        )

        guard evaluation.shouldGenerate, let trimmed = evaluation.trimmedUserText else {
            if ConversationTitlePlugin.verbose {
                logger.debug("\(Self.t)skip: policy declined userCount=\(userCount)")
            }
            return
        }

        guard let title = await ConversationTitleService.generateTitle(
            userMessage: trimmed,
            conversationId: conversationId
        ) else {
            if ConversationTitlePlugin.verbose {
                logger.debug("\(Self.t)skip: title generation returned nil")
            }
            return
        }

        let updated = ConversationTitleRuntimeBridge.updateConversationTitle(conversationId, title)
        if ConversationTitlePlugin.verbose {
            logger.info("\(Self.t)标题已更新: \"\(title)\" success=\(updated)")
        }
    }
}
