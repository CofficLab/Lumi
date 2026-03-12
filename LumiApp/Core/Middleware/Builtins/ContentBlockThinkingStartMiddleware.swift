import Foundation

/// 处理 contentBlockStart：识别 thinking block 开始并更新运行态/UI，然后短路事件下游。
@MainActor
final class ContentBlockThinkingStartMiddleware: ConversationTurnMiddleware {
    let id: String = "core.contentBlockThinkingStart"
    let order: Int = 7

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamEvent(eventType, _, rawEvent, _, conversationId) = event,
              eventType == .contentBlockStart else {
            await next(event, ctx)
            return
        }

        // 兼容不同 provider 的字段形态：只要能判断是 thinking block 即触发。
        if rawEvent.contains("\"type\":\"thinking\"") || rawEvent.contains("thinking") {
            ctx.runtimeStore.thinkingConversationIds.insert(conversationId)
            if ctx.env.selectedConversationId() == conversationId {
                ctx.ui.onThinkingStartedUI(conversationId)
            }
        }

        // 短路：该事件对核心 handler 不再有意义。
    }
}
