import SwiftUI

extension RootView {
    func onTaskCancellationRequested() {
        guard let conversationId = self.container.taskCancellationVM.conversationIdToCancel else { return }

        let runtimeStore = container.conversationRuntimeStore

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

        container.taskCancellationVM.consumeRequest()
    }
}
