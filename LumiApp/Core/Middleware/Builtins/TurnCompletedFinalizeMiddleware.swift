import Foundation

/// 处理 completed：清理流式运行态、结束 UI，并更新运行状态，然后短路事件下游。
@MainActor
final class TurnCompletedFinalizeMiddleware: ConversationTurnMiddleware {
    let id: String = "core.turnCompletedFinalize"
    let order: Int = 31

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .completed(conversationId) = event else {
            await next(event, ctx)
            return
        }

        ctx.runtimeStore.processingConversationIds.remove(conversationId)

        if ctx.env.selectedConversationId() == conversationId {
            ctx.ui.onTurnFinishedUI(conversationId)
        }

        ctx.runtimeStore.streamStateByConversation[conversationId] = .init(messageId: nil, messageIndex: nil)
        ctx.runtimeStore.pendingStreamTextByConversation[conversationId] = nil
        ctx.runtimeStore.pendingThinkingTextByConversation[conversationId] = nil
        ctx.runtimeStore.lastStreamFlushAtByConversation[conversationId] = nil
        ctx.runtimeStore.lastThinkingFlushAtByConversation[conversationId] = nil
        ctx.runtimeStore.streamStartedAtByConversation[conversationId] = nil
        ctx.runtimeStore.didReceiveFirstTokenByConversation.remove(conversationId)

        ctx.actions.updateRuntimeState(conversationId)
        // 短路：收尾逻辑已处理完毕。
    }
}

