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
            if message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let toolCalls = message.toolCalls,
               !(toolCalls.isEmpty) {
                var updated = message
                updated.content = toolSummaryContent(
                    toolCalls: toolCalls,
                    languagePreference: language
                )

                if Self.verbose {
                    AppLogger.core.info("\(Self.t) 空 content + toolCalls，追加工具摘要：\(toolCalls.count) 个")
                }

                await next(.responseReceived(updated, conversationId: conversationId), ctx)
            } else {
                await next(event, ctx)
            }

        case let .streamFinished(message, conversationId):
            guard message.role == .assistant else {
                await next(event, ctx)
                return
            }
            if message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let toolCalls = message.toolCalls,
               !(toolCalls.isEmpty) {
                var updated = message
                updated.content = toolSummaryContent(
                    toolCalls: toolCalls,
                    languagePreference: language
                )

                if Self.verbose {
                    AppLogger.core.info("\(Self.t) 流式结束 空 content + toolCalls，追加工具摘要：\(toolCalls.count) 个")
                }

                await next(.streamFinished(message: updated, conversationId: conversationId), ctx)
            } else {
                await next(event, ctx)
            }

        default:
            await next(event, ctx)
        }
    }

    private func toolSummaryContent(
        toolCalls: [ToolCall],
        languagePreference: LanguagePreference
    ) -> String {
        let toolSummary = toolCalls.map(\.name).joined(separator: "\n")
        let prefix = languagePreference == .chinese
            ? "正在执行 \(toolCalls.count) 个工具："
            : "Executing \(toolCalls.count) tools:"
        return prefix + "\n" + toolSummary
    }
}

