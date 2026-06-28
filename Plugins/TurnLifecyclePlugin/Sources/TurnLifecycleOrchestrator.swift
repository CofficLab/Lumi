import Foundation
import LumiCoreKit
import SuperLogKit
import os

enum TurnLifecycleOrchestrator: SuperLog {
    @MainActor
    static func handleMessageSaved(conversationId: UUID) {
        let phase = TurnLifecycleRuntimeBridge.loadTurnPhase(conversationId)
        guard phase == .processing else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑥ [TurnLifecycle] skip: phase=\(phase.rawValue)")
            }
            return
        }

        let messages = TurnLifecycleRuntimeBridge.loadMessages(conversationId)
        guard AgentTurnDerivation.isTurnComplete(messages: messages) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑥ [TurnLifecycle] skip: turn not complete")
            }
            return
        }

        guard let endReason = AgentTurnDerivation.turnEndReason(messages: messages) else {
            return
        }

        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑥ [TurnLifecycle] Turn 完成 → finishTurn + idle")
        }
        TurnLifecycleRuntimeBridge.finishAgentTurn(conversationId, endReason)
        TurnLifecycleRuntimeBridge.setTurnPhase(.idle, conversationId)
        TurnLifecycleRuntimeBridge.releaseConversationLock(conversationId)
    }
}
