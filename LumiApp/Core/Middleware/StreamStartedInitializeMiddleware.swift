import Foundation
import MagicKit

/// 处理 streamStarted：初始化流式运行态、清空 thinking、插入占位消息并触发 UI，然后短路事件下游。
@MainActor
final class StreamStartedInitializeMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "🌊"
    nonisolated static let verbose = true

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

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 流式开始 messageId=\(messageId.uuidString.prefix(8))")
        }

        ctx.runtimeStore.streamStateByConversation[conversationId] = .init(messageId: messageId)
        ctx.runtimeStore.streamingTextByConversation[conversationId] = ""
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

        ctx.actions.updateRuntimeState(conversationId)
        // 短路：streamStarted 已处理完毕，不进入核心 handler。
    }
}
