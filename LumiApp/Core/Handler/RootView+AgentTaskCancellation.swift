import SwiftUI

extension RootView {
    func onAgentTaskCancellationRequested(_ conversationId: UUID?) {
        guard let conversationId else { return }

        let messageSenderVM = container.MessageSenderVM
        let runtimeStore = container.conversationRuntimeStore

        messageSenderVM.cancelProcessing(for: conversationId, clearQueue: true)
        cancelTurnPipeline(for: conversationId)

        runtimeStore.clearRuntimeForTurnTermination(for: conversationId)
        runtimeStore.bumpStreamingPresentation()
        updateRuntimeState(for: conversationId)

        AppLogger.core.info("\(Self.t) 任务已取消 [\(String(conversationId.uuidString.prefix(8)))]")
        resetUIAfterAgentCancel(for: conversationId)

        let cancelMessage = container.ProjectVM.languagePreference == .chinese
            ? "⚠️ 生成已取消"
            : "⚠️ Generation cancelled"
        appendPipelineMessage(ChatMessage(role: .assistant, content: cancelMessage))

        container.agentTaskCancellationVM.consumeRequest()
    }
}
