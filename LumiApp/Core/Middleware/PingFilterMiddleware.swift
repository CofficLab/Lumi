import Foundation
import MagicKit

@MainActor
final class PingFilterMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "📟"
    nonisolated static let verbose = true

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
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 过滤 ping 事件（限流）")
            }
            return // 短路：过滤过于频繁的 ping
        }
        lastPingAtByConversation[conversationId] = now
        if Self.verbose {
            AppLogger.core.info("\(Self.t) 放行 ping 事件")
        }
        await next(event, ctx)
    }
}

