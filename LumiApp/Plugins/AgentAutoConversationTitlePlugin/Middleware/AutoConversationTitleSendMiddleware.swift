import Foundation
import MagicKit

/// 在管线继续后异步生成标题，避免阻塞后续 `send`。
@MainActor
struct AutoConversationTitleSuperSendMiddleware: SuperSendMiddleware {
    let id: String = "auto.conversation.title"
    let order: Int = 0

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        await next(ctx)
        let snapshot = (conversationId: ctx.conversationId, text: ctx.message.content, role: ctx.message.role)
        Task { @MainActor in
            await Self.applyIfNeeded(
                conversationId: snapshot.conversationId,
                userText: snapshot.text,
                role: snapshot.role,
                chatHistoryService: ctx.chatHistoryService,
                agentSessionConfig: ctx.agentSessionConfig
            )
        }
    }

    // MARK: - Private

    private static func applyIfNeeded(
        conversationId: UUID,
        userText: String,
        role: MessageRole,
        chatHistoryService: ChatHistoryService,
        agentSessionConfig: LLMVM
    ) async {
        guard let conversation = chatHistoryService.fetchConversation(id: conversationId) else { return }

        let newConversation = String(localized: "New Conversation", table: "AutoConversationTitlePlugin")
        let newChat = String(localized: "New Chat", table: "AutoConversationTitlePlugin")
        let policy = AutoConversationTitlePolicy()
        let preflight = policy.preflight(
            AutoConversationTitlePolicy.PreflightInput(
                role: role,
                userText: userText,
                currentTitle: conversation.title,
                newConversationTitle: newConversation,
                newChatTitlePrefix: newChat
            )
        )
        guard preflight.shouldGenerate, let trimmed = preflight.trimmedUserText else { return }

        let history = chatHistoryService.loadMessages(forConversationId: conversationId) ?? []
        let userCount = history.filter { $0.role == .user }.count
        guard userCount == 1 else { return }

        let config = agentSessionConfig.getCurrentConfig()
        let title = await chatHistoryService.generateConversationTitle(from: trimmed, config: config)
        chatHistoryService.updateConversationTitle(conversation, newTitle: title)
    }
}
