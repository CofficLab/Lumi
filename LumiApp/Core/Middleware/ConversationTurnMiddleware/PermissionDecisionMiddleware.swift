import Foundation
import MagicKit

/// 处理用户对权限请求的决策：
/// - `allowed=true`：触发工具执行并继续工具链（由 `ConversationTurnVM.executeToolAndContinue` 接管）
/// - `allowed=false`：生成拒绝的 tool 消息并交给后续 middleware 落库/追加
@MainActor
struct PermissionDecisionMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "✅/❌"
    nonisolated static let verbose = false

    let id: String = "core.permission-decision"
    /// 必须小于 `ToolResultTruncateMiddleware.order`，以便拒绝分支生成的 `.toolResultReceived` 能继续走截断与落库链路。
    let order: Int = 12

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .permissionDecision(allowed, request, conversationId) = event else {
            await next(event, ctx)
            return
        }

        if allowed {
            let toolCall = request.toToolCall()
            let languagePreference = ctx.env.languagePreference()
            Task { @MainActor in
                await ctx.actions.executeToolAndContinue(toolCall, conversationId, languagePreference)
            }
            // 允许后续链路继续（例如 trace logging）。
            await next(event, ctx)
            return
        }

        let rejectMessage = ChatMessage(
            role: .tool,
            content: "用户拒绝了执行 \(request.toolName) 的权限请求",
            toolCallID: request.toolCallID
        )

        // 拒绝分支：把拒绝消息作为 toolResultReceived 交给后续 core middleware 落库/追加。
        await next(.toolResultReceived(rejectMessage, conversationId: conversationId), ctx)
    }
}

