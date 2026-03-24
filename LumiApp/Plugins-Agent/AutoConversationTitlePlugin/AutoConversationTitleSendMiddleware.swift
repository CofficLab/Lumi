import Foundation
import MagicKit

/// 在管线继续后异步生成标题，避免阻塞后续 `send`。
@MainActor
struct AutoConversationTitleSendMiddleware: SendMiddleware {
    let id: String = "auto.conversation.title"
    let order: Int = 0

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        await next(ctx)
        let snapshot = (conversationId: ctx.conversationId, text: ctx.message.content, role: ctx.message.role)
        Task { @MainActor in
            await Self.applyIfNeeded(conversationId: snapshot.conversationId, userText: snapshot.text, role: snapshot.role)
        }
    }

    private static func applyIfNeeded(conversationId: UUID, userText: String, role: MessageRole) async {
        guard role == .user else { return }
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let container = RootViewContainer.shared
        let conversationVM = container.conversationVM
        guard let conversation = conversationVM.fetchConversation(id: conversationId) else { return }
        guard shouldAutoTitle(conversation.title) else { return }

        let history = await container.chatHistoryService.loadMessagesAsync(forConversationId: conversationId) ?? []
        let userCount = history.filter { $0.role == .user }.count
        guard userCount == 1 else { return }

        let config = container.agentSessionConfig.getCurrentConfig()
        let title = await conversationVM.generateConversationTitle(from: trimmed, config: config)
        conversationVM.updateConversationTitle(conversation, newTitle: title)
    }

    /// 与创建会话时的占位标题一致时才自动替换。
    private static func shouldAutoTitle(_ title: String) -> Bool {
        if title == "新对话" { return true }
        if title.hasPrefix("新会话") { return true }
        return false
    }
}