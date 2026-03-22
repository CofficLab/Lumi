import Foundation
import MagicKit

/// 处理 maxDepthReached：清理流式运行态并结束 UI，然后短路事件下游。
@MainActor
final class MaxDepthReachedFinalizeMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "⚠️"
    nonisolated static let verbose = true

    let id: String = "core.maxDepthReachedFinalize"
    let order: Int = 30

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .maxDepthReached(currentDepth, maxDepth, conversationId) = event else {
            await next(event, ctx)
            return
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 达到最大深度 current=\(currentDepth)/\(maxDepth)")
        }

        if ctx.env.selectedConversationId() == conversationId {
            ctx.projection.onTurnFinishedUI(conversationId)
        }

        ctx.runtimeStore.streamStateByConversation[conversationId] = .init(messageId: nil)
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

