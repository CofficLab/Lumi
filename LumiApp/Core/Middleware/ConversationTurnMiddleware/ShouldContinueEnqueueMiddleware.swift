import Foundation
import MagicKit

/// 接管 `.shouldContinue(depth:conversationId:)`：直接 enqueue 下一步轮次。
///
/// 目标：让 `ConversationTurnPipelineHandler` 的 terminal fallback 不再负责该控制流，
/// 进一步将“轮次编排”从 handler 中解耦到中间件层。
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
            AppLogger.core.info("\(Self.t) ⏩ enqueue next turn depth=\(depth) [\(conversationId.uuidString.prefix(8))]")
        }

        ctx.actions.enqueueTurnProcessing(conversationId, depth)
        // 不短路：允许后续 middleware（含插件）继续消费该事件，保持链路语义尽量一致。
        await next(event, ctx)
    }
}

