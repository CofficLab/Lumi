import Foundation

/// 处理 ping 心跳事件：更新 runtimeStore 与 UI，并短路事件下游。
@MainActor
final class PingHeartbeatMiddleware: ConversationTurnMiddleware {
    let id: String = "core.pingHeartbeat"
    let order: Int = 1

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamEvent(eventType, _, _, _, conversationId) = event,
              eventType == .ping else {
            await next(event, ctx)
            return
        }

        // `PingFilterMiddleware` 已负责限流，这里只做状态更新并短路。
        let now = Date()
        ctx.runtimeStore.lastHeartbeatByConversation[conversationId] = now
        if ctx.env.selectedConversationId() == conversationId {
            ctx.ui.setLastHeartbeatTime(now)
        }
        // 短路：ping 对核心 handler 无意义，避免继续传递。
    }
}

