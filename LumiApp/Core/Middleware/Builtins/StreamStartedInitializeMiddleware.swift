import Foundation

/// 处理 streamStarted：初始化流式运行态、清空 thinking、插入占位消息并触发 UI，然后短路事件下游。
@MainActor
final class StreamStartedInitializeMiddleware: ConversationTurnMiddleware {
    let id: String = "core.streamStartedInitialize"
    let order: Int = 2

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamStarted(messageId, conversationId) = event else {
            await next(event, ctx)
            return
        }

        ctx.runtimeStore.streamStateByConversation[conversationId] = .init(messageId: messageId, messageIndex: nil)
        ctx.runtimeStore.pendingStreamTextByConversation[conversationId] = ""
        ctx.runtimeStore.pendingThinkingTextByConversation[conversationId] = ""
        ctx.runtimeStore.lastStreamFlushAtByConversation[conversationId] = Date()
        ctx.runtimeStore.lastThinkingFlushAtByConversation[conversationId] = Date()
        ctx.runtimeStore.streamStartedAtByConversation[conversationId] = Date()
        ctx.runtimeStore.didReceiveFirstTokenByConversation.remove(conversationId)

        ctx.runtimeStore.thinkingTextByConversation[conversationId] = ""
        ctx.runtimeStore.thinkingConversationIds.remove(conversationId)

        if ctx.env.selectedConversationId() == conversationId {
            ctx.ui.setThinkingText("", conversationId)
            ctx.ui.setIsThinking(false, conversationId)
            ctx.ui.onStreamStartedUI(messageId, conversationId)
        }

        // 不在此处更新「模型已就绪」：streamStarted 在 sendStreamingMessage 之前发出，模型可能尚未加载或未下载。
        // 改为在收到首个 streamChunk 时再更新（StreamChunkAccumulateMiddleware），确保模型真正已就绪。

        let placeholderMessage = ChatMessage(id: messageId, role: .assistant, content: "", timestamp: Date())
        if ctx.env.selectedConversationId() == conversationId {
            ctx.actions.appendMessage(placeholderMessage)
            ctx.runtimeStore.streamStateByConversation[conversationId]?.messageIndex = ctx.actions.messages().count - 1
        }

        ctx.actions.updateRuntimeState(conversationId)
        // 短路：streamStarted 已处理完毕，不进入核心 handler。
    }
}

