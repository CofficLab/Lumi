import Foundation

/// 权限请求策略中间件（ConversationTurnEvent）
///
/// 目标：
/// - 对重复的权限请求做去噪（避免 UI 反复弹同一个请求）
/// - 统一“写入 runtimeStore + 更新 UI”的逻辑，减轻核心 handler 负担
@MainActor
struct PermissionPolicyMiddleware: ConversationTurnMiddleware {
    let id: String = "agent.permission-policy"
    let order: Int = 75

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .permissionRequested(request, conversationId) = event else {
            await next(event, ctx)
            return
        }

        // 去重：若同一会话已经有相同 toolCallID 的 pending request，直接短路。
        if let existing = ctx.runtimeStore.pendingPermissionByConversation[conversationId],
           existing.toolCallID == request.toolCallID {
            return
        }

        ctx.runtimeStore.pendingPermissionByConversation[conversationId] = request

        if ctx.env.selectedConversationId() == conversationId {
            ctx.ui.setPendingPermissionRequest(request, conversationId)
        }

        ctx.actions.updateRuntimeState(conversationId)
        // 短路：权限请求由中间件接管，核心 handler 不再重复写 UI/store。
    }
}

