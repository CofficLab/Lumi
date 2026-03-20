import Foundation
import MagicKit

/// 响应 `AgentTaskCancellationVM` 中的取消请求：清理队列、轮次任务、流式缓存与相关 UI。
enum CancelAgentTaskHandler: SuperLog {
    nonisolated static let emoji = "🛑"
    nonisolated static let verbose = false

    @MainActor
    static func handle(conversationId: UUID, turnVM: ConversationTurnVM) {
        turnVM.messageSenderVM.cancelProcessing(for: conversationId, clearQueue: true)
        turnVM.cancelTurnPipeline(for: conversationId)

        let store = turnVM.runtimeStore
        store.processingConversationIds.remove(conversationId)
        store.streamStateByConversation[conversationId] = ConversationRuntimeStore.StreamSessionState(
            messageId: nil,
            messageIndex: nil
        )
        store.pendingStreamTextByConversation[conversationId] = nil
        store.streamingTextByConversation[conversationId] = nil
        store.thinkingConversationIds.remove(conversationId)
        store.pendingPermissionByConversation[conversationId] = nil

        store.bumpStreamingPresentation()
        turnVM.updateRuntimeState(for: conversationId)

        AppLogger.core.info("\(Self.t)🛑 任务已取消 [\(String(conversationId.uuidString.prefix(8)))]")
        turnVM.resetUIAfterAgentCancel(for: conversationId)

        let cancelMessage = turnVM.projectVM.languagePreference == .chinese
            ? "⚠️ 生成已取消"
            : "⚠️ Generation cancelled"
        turnVM.appendPipelineMessage(ChatMessage(role: .assistant, content: cancelMessage))
    }
}
