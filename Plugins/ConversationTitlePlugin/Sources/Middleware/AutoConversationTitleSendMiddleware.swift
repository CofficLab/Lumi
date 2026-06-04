import Foundation
import LumiCoreKit

/// 在管线继续后异步生成标题，避免阻塞后续 `send`。
@MainActor
public struct AutoConversationTitleSuperSendMiddleware: SuperSendMiddleware {
    public let id: String = "auto.conversation.title"
    public let order: Int = 0

    public func handle(
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
                previousMessages: ctx.previousMessages,
                currentTitle: ctx.conversationTitleProvider(snapshot.conversationId),
                generateTitle: ctx.conversationTitleGenerator,
                updateTitle: ctx.conversationTitleUpdater
            )
        }
    }

    // MARK: - Private

    private static func applyIfNeeded(
        conversationId: UUID,
        userText: String,
        role: MessageRole,
        previousMessages: [ChatMessage],
        currentTitle: String?,
        generateTitle: @escaping @MainActor (_ userMessage: String) async -> String?,
        updateTitle: @escaping @MainActor (_ conversationId: UUID, _ title: String) -> Bool
    ) async {
        let newConversation = String(localized: "New Conversation", bundle: .module)
        let newChat = String(localized: "New Chat", bundle: .module)
        let policy = AutoConversationTitlePolicy()
        let preflight = policy.preflight(
            AutoConversationTitlePolicy.PreflightInput(
                role: role,
                userText: userText,
                currentTitle: currentTitle ?? "",
                newConversationTitle: newConversation,
                newChatTitlePrefix: newChat
            )
        )
        guard preflight.shouldGenerate, let trimmed = preflight.trimmedUserText else { return }

        let userCount = previousMessages.filter { $0.role == .user }.count
        guard userCount == 1 else { return }

        guard let title = await generateTitle(trimmed) else { return }
        _ = updateTitle(conversationId, title)
    }
}
