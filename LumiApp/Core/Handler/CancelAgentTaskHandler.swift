import Foundation
import MagicKit

/// 响应 `AgentTaskCancellationVM` 中的取消请求：清理队列、轮次任务、流式缓存与相关 UI。
enum CancelAgentTaskHandler: SuperLog {
    nonisolated static let emoji = "🛑"
    nonisolated static let verbose = false

    @MainActor
    static func handle(
        conversationId: UUID,
        turnPipelineHandler: ConversationTurnPipelineHandler,
        messageSenderVM: MessageQueueVM,
        runtimeStore: ConversationRuntimeStore,
        projectVM: ProjectVM
    ) {
        messageSenderVM.cancelProcessing(for: conversationId, clearQueue: true)
        turnPipelineHandler.cancelTurnPipeline(for: conversationId)

        let store = runtimeStore
        store.processingConversationIds.remove(conversationId)
        store.streamStateByConversation[conversationId] = ConversationRuntimeStore.StreamSessionState(messageId: nil)
        store.pendingStreamTextByConversation[conversationId] = nil
        store.streamingTextByConversation[conversationId] = nil
        store.thinkingConversationIds.remove(conversationId)
        store.pendingPermissionByConversation[conversationId] = nil

        store.turnContextsByConversation.removeValue(forKey: conversationId)

        store.bumpStreamingPresentation()
        turnPipelineHandler.updateRuntimeState(for: conversationId)

        AppLogger.core.info("\(Self.t)🛑 任务已取消 [\(String(conversationId.uuidString.prefix(8)))]")
        turnPipelineHandler.resetUIAfterAgentCancel(for: conversationId)

        let cancelMessage = projectVM.languagePreference == .chinese
            ? "⚠️ 生成已取消"
            : "⚠️ Generation cancelled"
        turnPipelineHandler.appendPipelineMessage(ChatMessage(role: .assistant, content: cancelMessage))
    }
}
