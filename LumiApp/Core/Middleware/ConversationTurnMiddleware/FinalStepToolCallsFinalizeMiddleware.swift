import Foundation
import MagicKit

/// 处理“最后一步仍请求工具”场景：补发中止 tool 结果、解释消息并结束轮次。
@MainActor
final class FinalStepToolCallsFinalizeMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "🧯"
    nonisolated static let verbose = true

    let id: String = "core.final-step-tool-calls.finalize"
    let order: Int = 29

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .finalStepToolCalls(toolCalls, depth, maxDepth, languagePreference, conversationId) = event else {
            await next(event, ctx)
            return
        }

        guard !toolCalls.isEmpty else {
            await next(.completed(conversationId: conversationId), ctx)
            return
        }

        for toolCall in toolCalls {
            let abortMessage = ChatMessage(
                role: .tool,
                content: "[Tool execution aborted by safety guard]",
                toolCallID: toolCall.id
            )
            await next(.toolResultReceived(abortMessage, conversationId: conversationId), ctx)
        }

        let explainMessage = ChatMessage.maxDepthToolLimitMessage(
            languagePreference: languagePreference,
            currentDepth: depth,
            maxDepth: maxDepth
        )
        await next(.responseReceived(explainMessage, conversationId: conversationId), ctx)
        await next(.completed(conversationId: conversationId), ctx)

        if Self.verbose {
            AppLogger.core.warning("\(Self.t)[\(conversationId)] 最后一步仍请求工具，已忽略并结束本轮")
        }
    }
}
