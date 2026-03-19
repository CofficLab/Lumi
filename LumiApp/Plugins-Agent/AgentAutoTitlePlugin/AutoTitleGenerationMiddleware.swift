import Foundation
import OSLog
import MagicKit

/// 自动生成会话标题中间件
///
/// 触发时机：
/// - 用户发送消息（`MessageSendEvent.sendMessage`）
///
/// 行为：
/// - 仅在插件侧判断是否需要生成标题（空消息/默认标题/是否已触发）。
/// - 条件满足时异步触发一次标题生成。
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

        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            if Self.verbose {
                os_log("\(Self.t)⏭️ 用户消息为空，跳过生成")
            }
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
            let expectedTitle = title
            let generateTitle = ctx.services.generateConversationTitle
            let updateTitleIfUnchanged = ctx.services.updateConversationTitleIfUnchanged

            // 使用普通 Task 继承当前执行器，避免跨线程访问非 Sendable 的 SwiftData 上下文。
            Task(priority: .background) {
                if Self.verbose {
                    os_log("\(Self.t)🔄 [\(conversationId)] 开始后台生成标题...")
                }
                let generatedTitle = await generateTitle(content, config)
                let updated = await updateTitleIfUnchanged(conversationId, expectedTitle, generatedTitle)
                if Self.verbose {
                    if updated {
                        os_log("\(Self.t)✅ [\(conversationId)] 对话标题已更新：\(generatedTitle)")
                    } else {
                        os_log("\(Self.t)ℹ️ [\(conversationId)] 标题在生成期间已变化，跳过更新")
                    }
                }
            }
        } else {
            if Self.verbose {
                if title.hasPrefix("新会话 ") == false {
                    os_log("\(Self.t)⏭️ 会话已有自定义标题，跳过生成")
                } else if hasTriggered {
                    os_log("\(Self.t)⏭️ 插件已触发过标题生成，跳过生成")
                } else {
                    os_log("\(Self.t)⏭️ 不满足生成条件，跳过生成")
                }
            }
        }

        await next(event, ctx)
    }
}
