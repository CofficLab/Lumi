import Foundation

/// 持久化并追加到 UI 的中间件
///
/// 接管：
/// - responseReceived
/// - toolResultReceived
///
/// 目标：
/// - 统一“追加到消息列表 + 落库 + runtimeState 更新”的逻辑
/// - 让核心 handler 更接近纯路由器
@MainActor
final class PersistAndAppendMiddleware: ConversationTurnMiddleware {
    let id: String = "core.persistAndAppend"
    let order: Int = 40

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        switch event {
        case let .responseReceived(message, conversationId):
            let list = ctx.actions.messages()
            if let idx = list.lastIndex(where: { $0.content == ChatMessage.loadingLocalModelSystemContentKey }) {
                var updated = list[idx]
                if message.isError {
                    updated.content = ChatMessage.loadingLocalModelFailedSystemContentKey
                } else {
                    updated.content = ChatMessage.loadingLocalModelDoneSystemContentKey
                }
                ctx.actions.updateMessage(updated, idx)
                await ctx.actions.saveMessage(updated, conversationId)
            }
            if ctx.env.selectedConversationId() == conversationId {
                ctx.actions.appendMessage(message)
            }
            await ctx.actions.saveMessage(message, conversationId)
            ctx.actions.updateRuntimeState(conversationId)
            return // 短路

        case let .toolResultReceived(result, conversationId):
            if ctx.env.selectedConversationId() == conversationId {
                ctx.actions.appendMessage(result)
            }
            await ctx.actions.saveMessage(result, conversationId)
            ctx.actions.updateRuntimeState(conversationId)
            return // 短路

        default:
            await next(event, ctx)
        }
    }
}

