import Foundation

/// 通过丢弃过于频繁的 thinking delta，实现按会话的节流/合并效果。
@MainActor
final class ThinkingDeltaThrottleMiddleware: ConversationTurnMiddleware {
    let id: String = "core.thinkingDeltaThrottle"
    let order: Int = 5

    private var lastForwardAtByConversation: [UUID: Date] = [:]
    private let minInterval: TimeInterval

    init(minInterval: TimeInterval = 0.12) {
        self.minInterval = minInterval
    }

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamEvent(eventType, _, _, _, conversationId) = event,
              eventType == .thinkingDelta else {
            await next(event, ctx)
            return
        }

        let now = Date()
        if let last = lastForwardAtByConversation[conversationId],
           now.timeIntervalSince(last) < minInterval {
            return // 短路：过滤过于频繁的 thinking delta
        }
        lastForwardAtByConversation[conversationId] = now
        await next(event, ctx)
    }
}

