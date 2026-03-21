import SwiftUI

extension RootView {
    func onAgentTaskCancellationRequested(_ conversationId: UUID?) {
        guard let conversationId else { return }

        let messageSenderVM = container.MessageSenderVM
        let turnPipelineHandler = container.conversationTurnPipelineHandler
        let runtimeStore = container.conversationRuntimeStore

        messageSenderVM.cancelProcessing(for: conversationId, clearQueue: true)
        turnPipelineHandler.cancelTurnPipeline(for: conversationId)

        runtimeStore.processingConversationIds.remove(conversationId)
        runtimeStore.streamStateByConversation[conversationId] = ConversationRuntimeStore.StreamSessionState(messageId: nil)
        runtimeStore.pendingStreamTextByConversation[conversationId] = nil
        runtimeStore.streamingTextByConversation[conversationId] = nil
        runtimeStore.thinkingConversationIds.remove(conversationId)
        runtimeStore.pendingPermissionByConversation[conversationId] = nil
        runtimeStore.turnContextsByConversation.removeValue(forKey: conversationId)

        runtimeStore.bumpStreamingPresentation()
        turnPipelineHandler.updateRuntimeState(for: conversationId)

        AppLogger.core.info("\(ConversationTurnPipelineHandler.t)🛑 任务已取消 [\(String(conversationId.uuidString.prefix(8)))]")
        turnPipelineHandler.resetUIAfterAgentCancel(for: conversationId)

        let cancelMessage = container.ProjectVM.languagePreference == .chinese
            ? "⚠️ 生成已取消"
            : "⚠️ Generation cancelled"
        turnPipelineHandler.appendPipelineMessage(ChatMessage(role: .assistant, content: cancelMessage))

        container.agentTaskCancellationVM.consumeRequest()
    }
}
