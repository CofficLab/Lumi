import Foundation
import MagicKit

/// 处理 completed：清理流式运行态、结束 UI，并更新运行状态，然后短路事件下游。
@MainActor
final class TurnCompletedFinalizeMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "🏁"
    nonisolated static let verbose = true

    let id: String = "core.turnCompletedFinalize"
    let order: Int = 31

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .completed(conversationId) = event else {
            await next(event, ctx)
            return
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 轮次完成")
        }

        ctx.runtimeStore.processingConversationIds.remove(conversationId)

        if ctx.env.selectedConversationId() == conversationId {
            ctx.ui.onTurnFinishedUI(conversationId)
        }

        ctx.runtimeStore.streamStateByConversation[conversationId] = .init(messageId: nil)
        ctx.runtimeStore.pendingStreamTextByConversation[conversationId] = nil
        ctx.runtimeStore.streamingTextByConversation[conversationId] = nil
        ctx.runtimeStore.pendingThinkingTextByConversation[conversationId] = nil
        ctx.runtimeStore.lastStreamFlushAtByConversation[conversationId] = nil
        ctx.runtimeStore.lastThinkingFlushAtByConversation[conversationId] = nil
        ctx.runtimeStore.streamStartedAtByConversation[conversationId] = nil
        ctx.runtimeStore.didReceiveFirstTokenByConversation.remove(conversationId)

        ctx.actions.updateRuntimeState(conversationId)

        // 发送对话轮次结束的系统消息
        let languagePreference = Self.loadLanguagePreference()
        let turnCompletedMessage = ChatMessage.turnCompletedSystemMessage(
            languagePreference: languagePreference
        )
        if ctx.env.selectedConversationId() == conversationId {
            ctx.actions.appendMessage(turnCompletedMessage)
        }
        await ctx.actions.saveMessage(turnCompletedMessage, conversationId)

        // 短路：收尾逻辑已处理完毕。
    }

    /// 从 PluginStateStore 加载语言偏好设置
    private static func loadLanguagePreference() -> LanguagePreference {
        if let data = PluginStateStore.shared.data(forKey: "Agent_LanguagePreference"),
           let preference = try? JSONDecoder().decode(LanguagePreference.self, from: data) {
            return preference
        }
        return .chinese
    }
}