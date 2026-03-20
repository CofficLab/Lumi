import Foundation
import MagicKit

/// 接管 `.shouldContinue(depth:conversationId:)`：直接 enqueue 下一步轮次。
@MainActor
struct ShouldContinueEnqueueMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "➡️"
    nonisolated static let verbose = true

    let id: String = "core.shouldContinue.enqueue"
    let order: Int = 1000

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .shouldContinue(depth, conversationId) = event else {
            await next(event, ctx)
            return
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t) ⏩ [\(conversationId.uuidString.prefix(8))] enqueue next turn depth=\(depth)")
        }

        // 深度超过上限：不再 enqueue，改为走统一 maxDepth 收尾链路。
        let guardResult = MaxDepthReachedGuard().evaluate(depth: depth, maxDepth: ctx.env.maxDepth)
        if case let .reached(currentDepth, maxDepth) = guardResult {
            if Self.verbose {
                AppLogger.core.info("\(Self.t) ⛔️ depth=\(currentDepth) > max=\(maxDepth)，触发 maxDepthReached [\(conversationId.uuidString.prefix(8))]")
            }
            await next(.maxDepthReached(currentDepth: currentDepth, maxDepth: maxDepth, conversationId: conversationId), ctx)
            return
        }

        ctx.actions.enqueueTurnProcessing(conversationId, depth)
        // 该事件只用于 enqueue 控制流，不需要继续向下游传播。
    }
}

