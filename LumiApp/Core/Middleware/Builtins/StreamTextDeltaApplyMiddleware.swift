import Foundation

/// 处理 streamEvent.textDelta：累积增量文本并按节流策略刷新 UI，然后短路事件下游。
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
              ctx.runtimeStore.streamStateByConversation[conversationId]?.messageId == messageId else {
            return
        }

        // 与 streamChunk 路径保持一致：
        // 避免每个 delta 都触发一次主线程列表更新，降低 SwiftUI 事务风暴风险。
        ctx.runtimeStore.pendingStreamTextByConversation[conversationId, default: ""] += content
        ctx.actions.flushPendingStreamText(
            conversationId,
            ctx.runtimeStore.pendingStreamTextByConversation[conversationId, default: ""].count >= ctx.env.immediateStreamFlushChars
        )

        // 短路：textDelta 已应用，无需进入核心 handler。
    }
}

