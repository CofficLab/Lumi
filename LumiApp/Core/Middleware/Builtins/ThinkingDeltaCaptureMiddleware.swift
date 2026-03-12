import Foundation

/// 处理 thinking delta：在允许捕获时累积 thinking 文本，并做 UI 增量刷新，然后短路事件下游。
@MainActor
final class ThinkingDeltaCaptureMiddleware: ConversationTurnMiddleware {
    let id: String = "core.thinkingDeltaCapture"
    let order: Int = 6

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamEvent(eventType, content, _, _, conversationId) = event,
              eventType == .thinkingDelta else {
            await next(event, ctx)
            return
        }

        guard ctx.env.captureThinkingContent else { return }
        guard !content.isEmpty else { return }

        let existing = ctx.runtimeStore.thinkingTextByConversation[conversationId, default: ""]
        guard existing.count < ctx.env.maxThinkingTextLength else { return }

        let remaining = ctx.env.maxThinkingTextLength - existing.count
        let appendPart = String(content.prefix(remaining))
        ctx.runtimeStore.thinkingTextByConversation[conversationId] = existing + appendPart

        if ctx.env.selectedConversationId() == conversationId, !appendPart.isEmpty {
            ctx.runtimeStore.pendingThinkingTextByConversation[conversationId, default: ""] += appendPart
            ctx.actions.flushPendingThinkingText(
                conversationId,
                ctx.runtimeStore.pendingThinkingTextByConversation[conversationId, default: ""].count >= ctx.env.immediateThinkingFlushChars
            )
        }

        // 短路：thinking delta 已处理完毕，不需要进入核心 handler。
    }
}

