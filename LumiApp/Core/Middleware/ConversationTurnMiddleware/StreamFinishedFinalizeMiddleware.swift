import Foundation
import MagicKit

/// 处理 streamFinished：刷新 UI 缓冲、拼装最终消息、落库，并清理流式运行态，然后短路事件下游。
@MainActor
final class StreamFinishedFinalizeMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "✅"
    nonisolated static let verbose = true

    let id: String = "core.streamFinishedFinalize"
    let order: Int = 20

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamFinished(message, conversationId) = event else {
            await next(event, ctx)
            return
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 流式结束，内容长度=\(message.content.count) 字符")
        }

        // 强制刷新当前 UI 缓冲的 streaming/thinking 增量文本。
        let now = Date()
        let pendingStream = ctx.runtimeStore.pendingStreamTextByConversation[conversationId] ?? ""
        if !pendingStream.isEmpty {
            ctx.runtimeStore.streamingTextByConversation[conversationId, default: ""] += pendingStream
            ctx.runtimeStore.pendingStreamTextByConversation[conversationId] = ""
            ctx.runtimeStore.lastStreamFlushAtByConversation[conversationId] = now
            if ctx.env.selectedConversationId() == conversationId {
                ctx.runtimeStore.bumpStreamingPresentation()
            }
        }

        let pendingThinking = ctx.runtimeStore.pendingThinkingTextByConversation[conversationId] ?? ""
        if !pendingThinking.isEmpty {
            if ctx.env.selectedConversationId() == conversationId {
                ctx.projection.appendThinkingText(pendingThinking, conversationId)
            }
            ctx.runtimeStore.pendingThinkingTextByConversation[conversationId] = ""
            ctx.runtimeStore.lastThinkingFlushAtByConversation[conversationId] = now
        }

        var finalMessage = message
        let thinkingText = ctx.runtimeStore.thinkingTextByConversation[conversationId] ?? ""
        if !thinkingText.isEmpty {
            finalMessage.thinkingContent = thinkingText
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 附加思考内容长度=\(thinkingText.count) 字符")
            }
        }

        await ctx.actions.saveMessage(finalMessage, conversationId)

        ctx.runtimeStore.streamStateByConversation[conversationId] = .init(messageId: nil)
        ctx.runtimeStore.thinkingConversationIds.remove(conversationId)

        if ctx.env.selectedConversationId() == conversationId {
            ctx.projection.onStreamFinishedUI(conversationId)
        }

        ctx.runtimeStore.pendingStreamTextByConversation[conversationId] = nil
        ctx.runtimeStore.streamingTextByConversation[conversationId] = nil
        ctx.runtimeStore.pendingThinkingTextByConversation[conversationId] = nil
        ctx.runtimeStore.lastStreamFlushAtByConversation[conversationId] = nil
        ctx.runtimeStore.lastThinkingFlushAtByConversation[conversationId] = nil
        ctx.runtimeStore.streamStartedAtByConversation[conversationId] = nil
        ctx.runtimeStore.didReceiveFirstTokenByConversation.remove(conversationId)

        ctx.actions.updateRuntimeState(conversationId)
        // 短路：streamFinished 已完全处理，不再进入核心 handler。
    }
}

