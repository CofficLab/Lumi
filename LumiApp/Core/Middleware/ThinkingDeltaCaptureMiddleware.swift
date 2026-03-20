import Foundation
import MagicKit

/// 处理 thinking delta：在允许捕获时累积 thinking 文本，并做 UI 增量刷新，然后短路事件下游。
/// 注意：累积长度超过 env.maxThinkingTextLength 时，超出部分会被截断且不会写入数据库。
@MainActor
final class ThinkingDeltaCaptureMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "💭"
    nonisolated static let verbose = true

    let id: String = "core.thinkingDeltaCapture"
    let order: Int = 6

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamEvent(eventType, content, _, _, conversationId) = event,
              eventType == .thinkingDelta else {
            await next(event, ctx)
            return
        }

        guard ctx.env.captureThinkingContent else { return }
        guard !content.isEmpty else { return }

        let existing = ctx.runtimeStore.thinkingTextByConversation[conversationId, default: ""]
        guard existing.count < ctx.env.maxThinkingTextLength else { return }

        let remaining = ctx.env.maxThinkingTextLength - existing.count
        let appendPart = String(content.prefix(remaining))
        ctx.runtimeStore.thinkingTextByConversation[conversationId] = existing + appendPart

        if ctx.env.selectedConversationId() == conversationId, !appendPart.isEmpty {
            ctx.runtimeStore.pendingThinkingTextByConversation[conversationId, default: ""] += appendPart
            ctx.actions.flushPendingThinkingText(
                conversationId,
                ctx.runtimeStore.pendingThinkingTextByConversation[conversationId, default: ""].count >= ctx.env.immediateThinkingFlushChars
            )
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 累积思考文本 +\(appendPart.count) 字符")
            }
        }

        // 短路：thinking delta 已处理完毕，不需要进入核心 handler。
    }
}

