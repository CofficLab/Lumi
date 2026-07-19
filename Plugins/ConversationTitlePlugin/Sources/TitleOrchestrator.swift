import Foundation
import LumiKernel
import SuperLogKit
import os

/// Listens for saved messages and generates conversation titles after the first user message.
enum TitleOrchestrator: SuperLog {
    nonisolated static let emoji = "✏️"
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-title")

    @MainActor
    static func handleMessageSaved(message: LumiChatMessage) {
        guard message.role == .user else { return }
        let conversationID = message.conversationID
        guard !ConversationTitleRuntimeBridge.inFlightConversationIds.contains(conversationID) else {
            if ConversationTitlePlugin.verbose {
                logger.debug("\(Self.t)skip: inFlight")
            }
            return
        }

        if ConversationTitlePlugin.verbose {
            logger.info("\(Self.t)首条用户消息已落库，准备生成标题")
        }

        Task { @MainActor in
            await generateIfNeeded(userMessage: message, conversationID: conversationID)
        }
    }

    @MainActor
    private static func generateIfNeeded(userMessage: LumiChatMessage, conversationID: UUID) async {
        ConversationTitleRuntimeBridge.inFlightConversationIds.insert(conversationID)
        defer { ConversationTitleRuntimeBridge.inFlightConversationIds.remove(conversationID) }

        guard let chatService = ConversationTitleRuntimeBridge.chatServiceProvider?() else {
            return
        }

        let newConversation = LumiPluginLocalization.string("New Conversation", bundle: .module)
        let newChat = LumiPluginLocalization.string("New Chat", bundle: .module)
        let currentTitle = chatService.conversations.first(where: { $0.id == conversationID })?.title ?? ""

        let policy = AutoConversationTitlePolicy()
        let messages = chatService.messages(for: conversationID)
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
            conversationID: conversationID
        ) else {
            if ConversationTitlePlugin.verbose {
                logger.debug("\(Self.t)skip: title generation returned nil")
            }
            return
        }

        let updated = chatService.updateConversationTitle(title, for: conversationID)
        if ConversationTitlePlugin.verbose {
            logger.info("\(Self.t)标题已更新: \"\(title)\" success=\(updated)")
        }
    }
}
