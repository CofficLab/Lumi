import Foundation
import MagicKit

/// 发送前防护中间件
///
/// 目标：
/// - 把“发送前边界处理”从核心链路剥离到插件侧，避免 `AgentRuntime`/协调器继续膨胀。
///
/// 当前策略（轻量且高收益）：
/// - 内容规范化：去掉首尾空白；若内容为空但有图片附件，仍允许发送
/// - 重复发送去重：极短时间内重复发送相同内容时直接短路
@MainActor
struct SendGuardMiddleware: MessageSendMiddleware, SuperLog {
    nonisolated static let emoji = "🔒"
    nonisolated static let verbose = true

    let id: String = "agent.send-guard"
    let order: Int = 90

    /// 认为“误触重复发送”的时间窗口（秒）。
    private let duplicateWindow: TimeInterval = 0.8

    func handle(
        event: MessageSendEvent,
        ctx: MessageSendMiddlewareContext,
        next: @escaping @MainActor (MessageSendEvent, MessageSendMiddlewareContext) async -> Void
    ) async {
        guard case let .sendMessage(message, conversationId) = event else {
            await next(event, ctx)
            return
        }

        let normalized = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAttachments = !message.images.isEmpty

        // 空内容 + 无附件：直接短路
        if normalized.isEmpty, !hasAttachments {
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 空内容 + 无附件：直接短路")
            }
            return
        }

        // 极短时间内重复发送相同内容：直接短路（常见于误触/快捷键连按）
        let now = Date()
        // 只在“模型仍在生成/流式中”时启用去重，避免用户在生成结束后立刻发送第二条消息被误判为重复。
        let isStreaming = ctx.runtimeStore.streamStateByConversation[conversationId]?.messageId != nil
        if let lastAt = ctx.runtimeStore.lastUserSendAtByConversation[conversationId],
           let lastContent = ctx.runtimeStore.lastUserSendContentByConversation[conversationId],
           isStreaming,
           now.timeIntervalSince(lastAt) < duplicateWindow,
           lastContent == normalized {
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 极短时间内重复发送相同内容：直接短路")
            }
            return
        }

        ctx.runtimeStore.lastUserSendAtByConversation[conversationId] = now
        ctx.runtimeStore.lastUserSendContentByConversation[conversationId] = normalized

        // 若内容被规范化（trim），则传递一个改写后的事件（保持图片附件不变）。
        if normalized != message.content {
            let rewritten = ChatMessage(role: message.role, content: normalized, images: message.images)
            await next(.sendMessage(rewritten, conversationId: conversationId), ctx)
            return
        }

        await next(event, ctx)
    }
}

