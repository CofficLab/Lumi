import Foundation

/// 处理 streamChunk：统计首 token 时间、累积 pending stream 文本并触发增量 flush，然后短路事件下游。
@MainActor
final class StreamChunkAccumulateMiddleware: ConversationTurnMiddleware {
    let id: String = "core.streamChunkAccumulate"
    let order: Int = 3

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamChunk(content, messageId, conversationId) = event else {
            await next(event, ctx)
            return
        }

        guard ctx.env.selectedConversationId() == conversationId,
              ctx.runtimeStore.streamStateByConversation[conversationId]?.messageId == messageId else {
            return
        }

        if !ctx.runtimeStore.didReceiveFirstTokenByConversation.contains(conversationId) {
            ctx.runtimeStore.didReceiveFirstTokenByConversation.insert(conversationId)
            if let startedAt = ctx.runtimeStore.streamStartedAtByConversation[conversationId] {
                let ttftMs = Date().timeIntervalSince(startedAt) * 1000.0
                ctx.ui.onStreamFirstTokenUI(conversationId, ttftMs)
            } else {
                ctx.ui.onStreamFirstTokenUI(conversationId, nil)
            }
        }

        ctx.runtimeStore.pendingStreamTextByConversation[conversationId, default: ""] += content
        ctx.actions.flushPendingStreamText(
            conversationId,
            ctx.runtimeStore.pendingStreamTextByConversation[conversationId, default: ""].count >= ctx.env.immediateStreamFlushChars
        )

        // 短路：streamChunk 已处理完毕，不进入核心 handler。
    }
}

