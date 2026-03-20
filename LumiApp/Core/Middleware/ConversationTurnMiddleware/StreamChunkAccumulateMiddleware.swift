import Foundation
import MagicKit

/// 处理 streamChunk：统计首 token 时间、累积 pending stream 文本并触发增量 flush，然后短路事件下游。
@MainActor
final class StreamChunkAccumulateMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = true

    let id: String = "core.streamChunkAccumulate"
    let order: Int = 3

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamChunk(content, messageId, conversationId) = event else {
            await next(event, ctx)
            return
        }

        guard ctx.env.selectedConversationId() == conversationId,
              ctx.runtimeStore.streamStateByConversation[conversationId]?.messageId == messageId else {
            return
        }

        if !ctx.runtimeStore.didReceiveFirstTokenByConversation.contains(conversationId) {
            ctx.runtimeStore.didReceiveFirstTokenByConversation.insert(conversationId)
            if let startedAt = ctx.runtimeStore.streamStartedAtByConversation[conversationId] {
                let ttftMs = Date().timeIntervalSince(startedAt) * 1000.0
                ctx.ui.onStreamFirstTokenUI(conversationId, ttftMs)
                if Self.verbose {
                    AppLogger.core.info("\(Self.t) 首 Token 时间=\(String(format: "%.0f", ttftMs))ms")
                }
            } else {
                ctx.ui.onStreamFirstTokenUI(conversationId, nil)
            }
            // 收到首个 token 时再更新「正在加载模型」为「模型已就绪」，避免未下载时误显示就绪
            let list = ctx.actions.messages()
            if let idx = list.lastIndex(where: { $0.content == ChatMessage.loadingLocalModelSystemContentKey }) {
                var updated = list[idx]
                updated.content = ChatMessage.loadingLocalModelDoneSystemContentKey
                ctx.actions.updateMessage(updated, idx)
                await ctx.actions.saveMessage(updated, conversationId)
            }
        }

        ctx.runtimeStore.pendingStreamTextByConversation[conversationId, default: ""] += content

        let pending = ctx.runtimeStore.pendingStreamTextByConversation[conversationId, default: ""]
        let force = pending.count >= ctx.env.immediateStreamFlushChars
        guard !pending.isEmpty else { return }

        let now = Date()
        let lastFlush = ctx.runtimeStore.lastStreamFlushAtByConversation[conversationId] ?? .distantPast
        guard force || now.timeIntervalSince(lastFlush) >= ctx.env.streamUIFlushInterval else { return }

        ctx.runtimeStore.streamingTextByConversation[conversationId, default: ""] += pending
        ctx.runtimeStore.pendingStreamTextByConversation[conversationId] = ""
        ctx.runtimeStore.lastStreamFlushAtByConversation[conversationId] = now

        ctx.runtimeStore.bumpStreamingPresentation()

        // 短路：streamChunk 已处理完毕，不进入核心 handler。
    }
}

