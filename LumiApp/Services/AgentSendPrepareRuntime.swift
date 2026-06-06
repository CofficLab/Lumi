import Foundation
import LumiCoreKit

/// App 层 SendPipeline 发送前准备（供 SendQueuePlugin 调用）。
@MainActor
enum AgentSendPrepareRuntime {
    static func runPreparePipeline(
        conversationId: UUID,
        message: ChatMessage,
        container: RootContainer,
        windowContainer: WindowContainer
    ) async -> [String] {
        let ctx = SendMessageContext(
            conversationId: conversationId,
            message: message,
            chatHistoryService: container.chatHistoryService,
            conversationService: container.conversationService,
            agentSessionConfig: container.agentSessionConfig,
            projectVM: windowContainer.projectVM,
            recentProjectsVM: container.recentProjectsVM,
            currentFileURL: windowContainer.editorVM.service.currentFileURL
        )
        ctx.abortTurn = {
            windowContainer.conversationSendStatusVM.setStatus(
                conversationId: conversationId,
                content: "检测到异常，已终止"
            )
            windowContainer.conversationSendStatusVM.clearStatus(conversationId: conversationId)
            container.conversationService.setTurnPhase(.idle, forConversationId: conversationId)
            container.chatHistoryService.clearQueueStatus(forConversationId: conversationId)
        }

        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ③ [SendPrepare] 开始 middlewares=\(container.pluginVM.getSuperSendMiddlewares().count)")
        }
        let pipeline = SendPipeline(middlewares: container.pluginVM.getSuperSendMiddlewares())
        await pipeline.run(ctx: ctx) { _ in }
        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ③ [SendPrepare] 完成 transientPrompts=\(ctx.transientSystemPrompts.count)")
        }
        return ctx.transientSystemPrompts
    }
}
