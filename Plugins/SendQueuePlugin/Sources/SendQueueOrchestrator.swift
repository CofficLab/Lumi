import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// 监听 DB 事件，出队 pending 消息、运行 SendPipeline 并启动 Turn。
enum SendQueueOrchestrator: SuperLog {
    nonisolated static let emoji = "📥"
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.send-queue")

    @MainActor
    static func handleDatabaseEvent(conversationId: UUID) {
        if SendQueueRuntimeBridge.inFlightConversationIds.contains(conversationId) {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ② [SendQueue] skip: inFlight")
            }
            return
        }

        let phase = SendQueueRuntimeBridge.loadTurnPhase(conversationId)
        let messages = SendQueueRuntimeBridge.loadMessages(conversationId)
        guard AgentTurnDerivation.shouldDequeueNextTurn(messages: messages, phase: phase) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ② [SendQueue] skip: shouldDequeue=false phase=\(phase.rawValue) pending=\(AgentTurnDerivation.hasPendingUserMessage(in: messages))")
            }
            return
        }
        guard !SendQueueRuntimeBridge.isConversationCancelled(conversationId) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ② [SendQueue] skip: cancelled")
            }
            return
        }
        guard SendQueueRuntimeBridge.tryAcquireConversationLock(conversationId) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ② [SendQueue] skip: lock busy")
            }
            return
        }

        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ② [SendQueue] 开始出队 → SendPrepare → processing")
        }
        Task { @MainActor in
            await performDequeueAndStart(conversationId: conversationId)
        }
    }

    @MainActor
    private static func performDequeueAndStart(conversationId: UUID) async {
        defer { SendQueueRuntimeBridge.releaseConversationLock(conversationId) }

        guard !SendQueueRuntimeBridge.isConversationCancelled(conversationId) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ② [SendQueue] abort: cancelled before dequeue")
            }
            return
        }

        SendQueueRuntimeBridge.inFlightConversationIds.insert(conversationId)
        defer { SendQueueRuntimeBridge.inFlightConversationIds.remove(conversationId) }

        SendQueueRuntimeBridge.clearConversationCancelled(conversationId)

        guard let message = SendQueueRuntimeBridge.dequeueNextPendingMessage(conversationId) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ② [SendQueue] abort: no pending message")
            }
            return
        }

        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ② [SendQueue] 已出队 user 消息 id=\(message.id.uuidString.prefix(8))，运行 SendPreparePipeline")
        }
        let transientPrompts = await SendQueueRuntimeBridge.runSendPreparePipeline(conversationId, message)
        SendQueueRuntimeBridge.storeTransientSystemPrompts(transientPrompts, conversationId)
        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ② [SendQueue] SendPrepare 完成 transientPrompts=\(transientPrompts.count) → setTurnPhase(processing)")
        }
        SendQueueRuntimeBridge.setTurnPhase(.processing, conversationId)
    }
}
