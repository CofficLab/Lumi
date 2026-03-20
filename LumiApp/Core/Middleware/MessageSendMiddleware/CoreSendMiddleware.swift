import Foundation
import MagicKit

/// 把 `SendMessageHandler.performCoreSend` 迁移到中间件层。
///
/// 行为：
/// 1) 若会话仍处于选中状态：投影到 UI 消息列表
/// 2) 落库保存
/// 3) 触发轮次处理（depth=0）
@MainActor
struct CoreSendMiddleware: MessageSendMiddleware, SuperLog {
    nonisolated static let emoji = "📨"
    nonisolated static let verbose = SendMessageHandler.verbose

    let id: String = "core.send-message.core-send"
    let order: Int = 120

    func handle(
        event: MessageSendEvent,
        ctx: MessageSendMiddlewareContext,
        next: @escaping @MainActor (MessageSendEvent, MessageSendMiddlewareContext) async -> Void
    ) async {
        guard case let .sendMessage(message, conversationId) = event else {
            await next(event, ctx)
            return
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📨 [\(String(conversationId.uuidString.prefix(8)))] 发送核心消息：\(message.content.prefix(50))")
        }

        // 1) 投影到当前消息列表（仅当该会话仍处于选中状态）
        if ctx.services.getSelectedConversationId() == conversationId {
            ctx.services.appendMessage(message)
        }

        // 2) 落库保存
        await ctx.services.saveMessage(message, conversationId)

        // 3) 触发轮次处理（深度从 0 开始）
        ctx.services.enqueueTurnProcessing(conversationId, 0)

        // 短路：core send 作为链尾核心逻辑，不调用 next。
    }
}

