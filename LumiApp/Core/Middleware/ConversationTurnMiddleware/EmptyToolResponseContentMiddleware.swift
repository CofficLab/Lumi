import Foundation
import MagicKit

/// 当 assistant 最终消息 `content` 为空但包含 `toolCalls` 时，
/// 追加用于展示的“正在执行/Executing 工具摘要”内容。
@MainActor
struct EmptyToolResponseContentMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "🧩"
    nonisolated static let verbose = true

    let id: String = "core.emptyToolResponseContent"
    let order: Int = 10

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        let language = ctx.env.languagePreference()

        switch event {
        case let .responseReceived(message, conversationId):
            guard message.role == .assistant else {
                await next(event, ctx)
                return
            }
            switch EmptyToolResponseContentGuard().evaluate(
                content: message.content,
                toolCalls: message.toolCalls,
                languagePreference: language
            ) {
            case .proceed:
                await next(event, ctx)
            case .updatedContent(let updatedContent):
                var updated = message
                updated.content = updatedContent

                if let toolCalls = message.toolCalls, Self.verbose {
                    AppLogger.core.info("\(Self.t) 空 content + toolCalls，追加工具摘要：\(toolCalls.count) 个")
                }

                await next(.responseReceived(updated, conversationId: conversationId), ctx)
            }

        case let .streamFinished(message, conversationId):
            guard message.role == .assistant else {
                await next(event, ctx)
                return
            }
            switch EmptyToolResponseContentGuard().evaluate(
                content: message.content,
                toolCalls: message.toolCalls,
                languagePreference: language
            ) {
            case .proceed:
                await next(event, ctx)
            case .updatedContent(let updatedContent):
                var updated = message
                updated.content = updatedContent

                if let toolCalls = message.toolCalls, Self.verbose {
                    AppLogger.core.info("\(Self.t) 流式结束 空 content + toolCalls，追加工具摘要：\(toolCalls.count) 个")
                }

                await next(.streamFinished(message: updated, conversationId: conversationId), ctx)
            }

        default:
            await next(event, ctx)
        }
    }
}

