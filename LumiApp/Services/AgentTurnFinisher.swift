import Foundation
import LumiCoreKit

/// App 层 Turn 收尾：队列、状态 UI、TurnFinished 管线。
@MainActor
final class AgentTurnFinisher {
    private let container: RootContainer
    private let windowContainer: WindowContainer

    init(container: RootContainer, windowContainer: WindowContainer) {
        self.container = container
        self.windowContainer = windowContainer
    }

    func finish(conversationId: UUID, endReason: TurnEndReason) {
        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑦ [TurnFinisher] finish reason=\(String(describing: endReason))")
        }
        container.chatHistoryService.clearQueueStatus(forConversationId: conversationId)
        windowContainer.conversationSendStatusVM.clearStatus(conversationId: conversationId)

        let middlewares = container.pluginVM.getSuperSendMiddlewares()
        let chatHistoryService = container.chatHistoryService
        let projectVM = windowContainer.projectVM
        let conversationVM = windowContainer.conversationVM

        Task {
            let turnMessages = chatHistoryService.loadMessages(forConversationId: conversationId) ?? []
            let ctx = AppTurnFinishedContext(
                conversationId: conversationId,
                endReason: endReason,
                turnMessages: turnMessages,
                chatHistoryService: chatHistoryService,
                projectVM: projectVM,
                conversationVM: conversationVM
            )
            let pipeline = SendPipeline(middlewares: middlewares)
            await pipeline.runTurnFinished(ctx: ctx)
        }

        NotificationCenter.postAgentConversationSendTurnFinished(conversationId: conversationId)
        NotificationCenter.postAgentTurnFinished(conversationId: conversationId)
    }
}
