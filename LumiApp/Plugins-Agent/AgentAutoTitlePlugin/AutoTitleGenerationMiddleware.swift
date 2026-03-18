import Foundation
import OSLog
import MagicKit

/// 自动生成会话标题中间件
///
/// 触发时机：
/// - 用户发送消息（`MessageSendEvent.sendMessage`）
///
/// 行为：
/// - 若对话标题仍是默认"新会话 …"，且插件未记录过触发，则异步触发一次标题生成。
@MainActor
struct AutoTitleGenerationMiddleware: MessageSendMiddleware, SuperLog {
    nonisolated static let emoji = "🏷️"
    nonisolated static let verbose = true
    let id: String = "agent.auto-title.generate"
    let order: Int = 100

    func handle(
        event: MessageSendEvent,
        ctx: MessageSendMiddlewareContext,
        next: @escaping @MainActor (MessageSendEvent, MessageSendMiddlewareContext) async -> Void
    ) async {
        guard case let .sendMessage(message, conversationId) = event, message.role == .user else {
            await next(event, ctx)
            return
        }

        let title = ctx.services.getConversationTitle(conversationId) ?? ""
        let hasTriggered = await AutoTitleGenerationStore.shared.hasTriggered(conversationId: conversationId)
        let shouldGenerate = title.hasPrefix("新会话 ") && !hasTriggered

        if shouldGenerate {
            if Self.verbose {
                os_log("\(Self.t)🎯 [\(conversationId)] 检测到需要生成标题")
            }

            await AutoTitleGenerationStore.shared.markTriggered(conversationId: conversationId)
            let config = ctx.services.getCurrentConfig()
            let content = message.content
            let autoGenerate = ctx.services.autoGenerateConversationTitleIfNeeded

            // 生成标题属于"后台辅助任务"，尽量不与 UI/流式渲染竞争主线程与高优先级执行资源。
            Task.detached(priority: .background) {
                if Self.verbose {
                    os_log("\(Self.t)🔄 [\(conversationId)] 开始后台生成标题...")
                }
                await autoGenerate(conversationId, content, config)
            }
        } else {
            if Self.verbose {
                if title.hasPrefix("新会话 ") == false {
                    os_log("\(Self.t)⏭️ 会话已有自定义标题，跳过生成")
                } else if hasTriggered {
                    os_log("\(Self.t)⏭️ 插件已触发过标题生成，跳过生成")
                }
            }
        }

        await next(event, ctx)
    }
}
