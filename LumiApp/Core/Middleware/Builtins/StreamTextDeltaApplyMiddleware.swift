import Foundation

/// 处理 streamEvent.textDelta：把增量文本应用到占位消息上，然后短路事件下游。
@MainActor
final class StreamTextDeltaApplyMiddleware: ConversationTurnMiddleware {
    let id: String = "core.streamTextDeltaApply"
    let order: Int = 9

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamEvent(eventType, content, _, messageId, conversationId) = event,
              eventType == .textDelta else {
            await next(event, ctx)
            return
        }

        guard ctx.env.selectedConversationId() == conversationId,
              ctx.runtimeStore.streamStateByConversation[conversationId]?.messageId == messageId,
              let index = ctx.runtimeStore.streamStateByConversation[conversationId]?.messageIndex,
              index < ctx.actions.messages().count else {
            return
        }

        var currentMessage = ctx.actions.messages()[index]
        currentMessage.content += content
        ctx.actions.updateMessage(currentMessage, index)

        // 短路：textDelta 已应用，无需进入核心 handler。
    }
}

