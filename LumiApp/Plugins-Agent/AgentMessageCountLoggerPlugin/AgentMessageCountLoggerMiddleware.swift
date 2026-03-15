import Foundation
import OSLog
import MagicKit

/// 消息数量日志中间件
///
/// 目标：
/// - 在发送消息时输出当前对话的消息数量日志
@MainActor
struct AgentMessageCountLoggerMiddleware: MessageSendMiddleware, SuperLog {
    nonisolated static let emoji = "📊"
    nonisolated static let verbose = true
    let id: String = "agent.message-count-logger"
    let order: Int = 95

    func handle(
        event: MessageSendEvent,
        ctx: MessageSendMiddlewareContext,
        next: @escaping @MainActor (MessageSendEvent, MessageSendMiddlewareContext) async -> Void
    ) async {
        guard case let .sendMessage(message, conversationId) = event, message.role == .user else {
            await next(event, ctx)
            return
        }

        // 获取当前对话的消息数量并输出日志
        let messageCount = ctx.services.getMessageCount(conversationId)

        // 使用 SuperLog 风格输出日志
        os_log("\(Self.t)🫧 当前消息数量：\(messageCount)")

        // 直接传递事件，不修改消息内容
        await next(event, ctx)
    }
}
