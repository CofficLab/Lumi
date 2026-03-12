import Foundation

/// 忽略对核心渲染无意义的 streamEvent 类型，减少核心 handler 分支与下游开销。
@MainActor
final class StreamEventIgnoreMiddleware: ConversationTurnMiddleware {
    let id: String = "core.streamEventIgnore"
    let order: Int = 8

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamEvent(eventType, _, _, _, _) = event else {
            await next(event, ctx)
            return
        }

        switch eventType {
        case .contentBlockStop, .signatureDelta, .inputJsonDelta, .messageDelta:
            // 这些事件要么用于底层协议，要么已在其他分支处理/无 UI 价值：直接短路。
            return
        default:
            await next(event, ctx)
        }
    }
}

