import Foundation
import HttpKit
import LLMKit
import LumiCoreKit
import SuperLogKit
import os

/// 监听 DB 事件并驱动 LLM 发送 + 写库。
enum SenderOrchestrator: SuperLog {
    nonisolated static let emoji = "📬"
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-sender")

    @MainActor
    static func handleMessageSaved(conversationId: UUID) {
        if RuntimeBridge.inFlightConversationIds.contains(conversationId) {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] skip: inFlight")
            }
            return
        }

        let phase = RuntimeBridge.loadTurnPhase(conversationId)
        guard phase == .processing else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] skip: phase=\(phase.rawValue)")
            }
            return
        }
        guard !RuntimeBridge.isConversationCancelled(conversationId) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] skip: cancelled")
            }
            return
        }

        let messages = RuntimeBridge.loadMessages(conversationId)
        guard AgentTurnDerivation.shouldRequestLLM(messages: messages) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] skip: shouldRequestLLM=false")
            }
            return
        }
        guard RuntimeBridge.tryAcquireConversationLock(conversationId) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] skip: lock busy")
            }
            return
        }

        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] 开始 LLM 请求 messages=\(messages.count)")
        }
        Task { @MainActor in
            await performSend(conversationId: conversationId, storageMessages: messages)
        }
    }

    @MainActor
    private static func performSend(conversationId: UUID, storageMessages: [ChatMessage]) async {
        defer { RuntimeBridge.releaseConversationLock(conversationId) }

        guard !RuntimeBridge.isConversationCancelled(conversationId) else { return }

        RuntimeBridge.inFlightConversationIds.insert(conversationId)
        defer { RuntimeBridge.inFlightConversationIds.remove(conversationId) }

        let pruned = RuntimeBridge.prepareMessagesForLLM(conversationId, storageMessages)
        let systemPrompts = RuntimeBridge.consumeTransientSystemPrompts(conversationId)
        let request = LLMSendRequest(
            conversationId: conversationId,
            messages: pruned,
            additionalSystemPrompts: systemPrompts
        )
        let dependencies = RuntimeBridge.makeLLMSendDependencies(conversationId)

        let result = await AgentLLMSender.send(request, dependencies)

        guard !RuntimeBridge.isConversationCancelled(conversationId) else { return }

        switch result {
        case let .success(assistantMessage):
            let toolCount = assistantMessage.toolCalls?.count ?? 0
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] LLM 成功 toolCalls=\(toolCount) → saveMessage")
            }
            let processed = RuntimeBridge.evaluateToolPermissions(assistantMessage, conversationId)
            RuntimeBridge.saveMessage(processed, conversationId)

        case .cancelled:
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] LLM 已取消 → finishTurn")
            }
            RuntimeBridge.setTurnPhase(.idle, conversationId)
            RuntimeBridge.finishAgentTurn(conversationId, .cancelled)

        case let .failed(error):
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ④ [MessageSender] LLM 失败: \(error.localizedDescription) → finishTurn")
            }
            let providerId = RuntimeBridge.currentProviderId(conversationId)
            let errorMessage = RuntimeBridge.buildLLMErrorMessage(error, conversationId, providerId)
            RuntimeBridge.saveMessage(errorMessage, conversationId)
            RuntimeBridge.setTurnPhase(.idle, conversationId)
            RuntimeBridge.finishAgentTurn(conversationId, .failed(error.localizedDescription))
        }
    }
}
