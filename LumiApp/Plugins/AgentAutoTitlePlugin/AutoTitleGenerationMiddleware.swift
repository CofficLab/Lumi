import Foundation

/// 自动生成会话标题中间件
///
/// 触发时机：
/// - 用户发送消息（`MessageSendEvent.sendMessage`）
///
/// 行为：
/// - 若对话标题仍是默认“新会话 …”，且未生成过标题，则异步触发一次标题生成。
@MainActor
struct AutoTitleGenerationMiddleware: MessageSendMiddleware {
    let id: String = "agent.auto-title.generate"
    let order: Int = 100

    func handle(
        event: MessageSendEvent,
        ctx: MessageSendMiddlewareContext,
        next: @escaping @MainActor (MessageSendEvent, MessageSendMiddlewareContext) async -> Void
    ) async {
        if case let .sendMessage(message, conversationId) = event, message.role == .user {
            let title = ctx.services.getConversationTitle(conversationId) ?? ""
            let shouldGenerate = title.hasPrefix("新会话 ") && !ctx.services.hasGeneratedTitle(conversationId)

            if shouldGenerate {
                ctx.services.setTitleGenerated(true, conversationId)
                let config = ctx.services.getCurrentConfig()
                let content = message.content
                let autoGenerate = ctx.services.autoGenerateConversationTitleIfNeeded

                // 生成标题属于“后台辅助任务”，尽量不与 UI/流式渲染竞争主线程与高优先级执行资源。
                Task.detached(priority: .background) {
                    await autoGenerate(conversationId, content, config)
                }
            }
        }

        await next(event, ctx)
    }
}

