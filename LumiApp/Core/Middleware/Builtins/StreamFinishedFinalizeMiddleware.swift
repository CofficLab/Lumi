import Foundation

/// 处理 streamFinished：刷新 UI 缓冲、拼装最终消息、落库，并清理流式运行态，然后短路事件下游。
@MainActor
final class StreamFinishedFinalizeMiddleware: ConversationTurnMiddleware {
    let id: String = "core.streamFinishedFinalize"
    let order: Int = 20

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamFinished(message, conversationId) = event else {
            await next(event, ctx)
            return
        }

        ctx.actions.flushPendingStreamText(conversationId, true)
        ctx.actions.flushPendingThinkingText(conversationId, true)

        var finalMessage = message
        let thinkingText = ctx.runtimeStore.thinkingTextByConversation[conversationId] ?? ""
        if !thinkingText.isEmpty {
            finalMessage.thinkingContent = thinkingText
        }

        if ctx.env.selectedConversationId() == conversationId,
           let index = ctx.runtimeStore.streamStateByConversation[conversationId]?.messageIndex,
           index < ctx.actions.messages().count {
            ctx.actions.updateMessage(finalMessage, index)
        }

        await ctx.actions.saveMessage(finalMessage, conversationId)

        ctx.runtimeStore.streamStateByConversation[conversationId] = .init(messageId: nil, messageIndex: nil)
        ctx.runtimeStore.thinkingConversationIds.remove(conversationId)

        if ctx.env.selectedConversationId() == conversationId {
            ctx.ui.onStreamFinishedUI(conversationId)
        }

        ctx.runtimeStore.pendingStreamTextByConversation[conversationId] = nil
        ctx.runtimeStore.pendingThinkingTextByConversation[conversationId] = nil
        ctx.runtimeStore.lastStreamFlushAtByConversation[conversationId] = nil
        ctx.runtimeStore.lastThinkingFlushAtByConversation[conversationId] = nil
        ctx.runtimeStore.streamStartedAtByConversation[conversationId] = nil
        ctx.runtimeStore.didReceiveFirstTokenByConversation.remove(conversationId)

        ctx.actions.updateRuntimeState(conversationId)
        // 短路：streamFinished 已完全处理，不再进入核心 handler。
    }
}

