import Foundation
import MagicKit

/// 截断过长的 tool result content，避免 UI/存储/插件链处理时承载过多文本。
///
/// 这是把 `ConversationTurnVM` 中的 `truncateToolResultIfNeeded` 逻辑迁移为中间件后的实现。
@MainActor
struct ToolResultTruncateMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "✂️"
    nonisolated static let verbose = true

    let id: String = "core.toolResult.truncate"
    let order: Int = 15

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .toolResultReceived(result, conversationId) = event else {
            await next(event, ctx)
            return
        }

        let maxLen = ctx.env.maxToolResultLength
        guard result.content.count > maxLen else {
            await next(event, ctx)
            return
        }

        let prefix = String(result.content.prefix(maxLen))
        var updated = result
        updated.content = "\(prefix)\n\n... [Tool output truncated to \(maxLen) characters]"

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 截断 tool 输出：\(result.content.count) -> \(maxLen)")
        }

        await next(.toolResultReceived(updated, conversationId: conversationId), ctx)
    }
}

