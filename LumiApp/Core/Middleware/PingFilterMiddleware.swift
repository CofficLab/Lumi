import Foundation

@MainActor
final class PingFilterMiddleware: ConversationTurnMiddleware {
    let id: String = "core.pingFilter"
    let order: Int = 0

    private var lastPingAtByConversation: [UUID: Date] = [:]
    private let minInterval: TimeInterval

    init(minInterval: TimeInterval = 0.8) {
        self.minInterval = minInterval
    }

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

        let now = Date()
        if let last = lastPingAtByConversation[conversationId],
           now.timeIntervalSince(last) < minInterval {
            return // 短路：过滤过于频繁的 ping
        }
        lastPingAtByConversation[conversationId] = now
        await next(event, ctx)
    }
}

