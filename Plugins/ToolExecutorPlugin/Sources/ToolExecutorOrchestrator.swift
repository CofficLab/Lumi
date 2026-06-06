import Foundation
import LumiCoreKit
import SuperLogKit
import os

enum ToolExecutorOrchestrator: SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-executor")

    @MainActor
    static func handleMessageSaved(conversationId: UUID) {
        let phase = ToolExecutorRuntimeBridge.loadTurnPhase(conversationId)
        guard phase == .processing else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑤ [ToolExecutor] skip: phase=\(phase.rawValue)")
            }
            return
        }
        guard !ToolExecutorRuntimeBridge.isConversationCancelled(conversationId) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑤ [ToolExecutor] skip: cancelled")
            }
            return
        }

        let messages = ToolExecutorRuntimeBridge.loadMessages(conversationId)
        guard AgentTurnDerivation.shouldExecuteTools(messages: messages, phase: phase) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑤ [ToolExecutor] skip: shouldExecuteTools=false")
            }
            return
        }
        guard let last = AgentTurnDerivation.lastDrivableMessage(in: messages), last.role == .assistant else { return }
        guard ToolExecutorRuntimeBridge.tryAcquireConversationLock(conversationId) else {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑤ [ToolExecutor] skip: lock busy")
            }
            return
        }

        let toolNames = last.toolCalls?.map(\.name).joined(separator: ", ") ?? ""
        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑤ [ToolExecutor] 开始执行 tools=[\(toolNames)]")
        }
        Task { @MainActor in
            await performExecution(conversationId: conversationId, assistantMessage: last)
        }
    }

    @MainActor
    private static func performExecution(conversationId: UUID, assistantMessage: ChatMessage) async {
        defer { ToolExecutorRuntimeBridge.releaseConversationLock(conversationId) }

        if await ToolExecutorRuntimeBridge.presentToolPermissionIfNeeded(assistantMessage, conversationId) {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑤ [ToolExecutor] 等待工具授权 → awaitingPermission")
            }
            ToolExecutorRuntimeBridge.setTurnPhase(.awaitingPermission, conversationId)
            return
        }

        let summary = await ToolExecutorRuntimeBridge.executeToolCalls(assistantMessage, conversationId)

        if summary.hadUserRejection {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑤ [ToolExecutor] 用户拒绝 → finishTurn")
            }
            ToolExecutorRuntimeBridge.setConversationStatus(conversationId, "用户拒绝执行工具，已结束回合")
            ToolExecutorRuntimeBridge.finishAgentTurn(conversationId, .userRejection)
            ToolExecutorRuntimeBridge.setTurnPhase(.idle, conversationId)
            return
        }

        if summary.hasAwaitingUserResponse {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑤ [ToolExecutor] 等待用户回答 → awaitingUserResponse")
            }
            ToolExecutorRuntimeBridge.setConversationStatus(conversationId, "等待您的选择…")
            ToolExecutorRuntimeBridge.setTurnPhase(.awaitingUserResponse, conversationId)
            return
        }

        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑤ [ToolExecutor] 工具执行完成 → messageSaved 触发下一轮")
        }
    }
}
