import Foundation
import LumiCoreKit
import os
import SuperLogKit

enum ToolExecutorOrchestrator: SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-executor")

    @MainActor
    static func handleMessageSaved(conversationId: UUID) {
        let phase = ToolExecutorRuntimeBridge.loadTurnPhase(conversationId)
        guard phase == .processing else {
            if Self.verbose {
                Self.logger.info("\(Self.t)skip: phase=\(phase.rawValue)")
            }
            return
        }
        guard !ToolExecutorRuntimeBridge.isConversationCancelled(conversationId) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)skip: cancelled")
            }
            return
        }

        let messages = ToolExecutorRuntimeBridge.loadMessages(conversationId)
        guard AgentTurnDerivation.shouldExecuteTools(messages: messages, phase: phase) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)skip: shouldExecuteTools=false")
            }
            return
        }
        guard let last = AgentTurnDerivation.lastDrivableMessage(in: messages), last.role == .assistant else { return }
        guard ToolExecutorRuntimeBridge.tryAcquireConversationLock(conversationId) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)skip: lock busy")
            }
            return
        }

        let toolNames = last.toolCalls?.map(\.name).joined(separator: ", ") ?? ""
        if Self.verbose {
            Self.logger.info("\(Self.t)开始执行 tools=[\(toolNames)]")
        }
        Task { @MainActor in
            await performExecution(conversationId: conversationId, assistantMessage: last)
        }
    }

    @MainActor
    private static func performExecution(conversationId: UUID, assistantMessage: AgentChatMessage) async {
        defer { ToolExecutorRuntimeBridge.releaseConversationLock(conversationId) }

        if await ToolExecutorRuntimeBridge.presentToolPermissionIfNeeded(assistantMessage, conversationId) {
            if Self.verbose {
                Self.logger.info("\(Self.t)等待工具授权 → awaitingPermission")
            }
            ToolExecutorRuntimeBridge.setTurnPhase(.awaitingPermission, conversationId)
            return
        }

        let summary = await ToolExecutorRuntimeBridge.executeToolCalls(assistantMessage, conversationId)

        if summary.hadUserRejection {
            if Self.verbose {
                Self.logger.info("\(Self.t)用户拒绝 → finishTurn")
            }
            ToolExecutorRuntimeBridge.setConversationStatus(conversationId, "用户拒绝执行工具，已结束回合")
            ToolExecutorRuntimeBridge.finishAgentTurn(conversationId, .userRejection)
            ToolExecutorRuntimeBridge.setTurnPhase(.idle, conversationId)
            return
        }

        if summary.hasAwaitingUserResponse {
            if Self.verbose {
                Self.logger.info("\(Self.t)等待用户回答 → awaitingUserResponse")
            }
            ToolExecutorRuntimeBridge.setConversationStatus(conversationId, "等待您的选择…")
            ToolExecutorRuntimeBridge.setTurnPhase(.awaitingUserResponse, conversationId)
            return
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)工具执行完成 → messageSaved 触发下一轮")
        }
    }
}
