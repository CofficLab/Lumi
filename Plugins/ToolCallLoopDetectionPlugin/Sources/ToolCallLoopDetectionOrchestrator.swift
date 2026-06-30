import Foundation
import LumiCoreKit
import SuperLogKit
import os

enum ToolCallLoopDetectionOrchestrator: SuperLog {
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-call-loop-detection")

    @MainActor
    static func handleMessageSaved(conversationId: UUID) {
        let phase = ToolCallLoopDetectionRuntimeBridge.loadTurnPhase(conversationId)
        guard phase == .processing else {
            if Self.verbose {
                Self.logger.info("\(Self.t)skip: phase=\(phase.rawValue)")
            }
            return
        }
        guard !ToolCallLoopDetectionRuntimeBridge.isConversationCancelled(conversationId) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)skip: cancelled")
            }
            return
        }

        let messages = ToolCallLoopDetectionRuntimeBridge.loadMessages(conversationId)
        guard AgentTurnDerivation.shouldRequestLLM(messages: messages) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)skip: shouldRequestLLM=false")
            }
            return
        }

        guard let pattern = ToolCallLoopDetector.detect(in: messages) else { return }
        handleDetectedLoop(pattern, conversationId: conversationId)
    }

    @MainActor
    private static func handleDetectedLoop(_ pattern: ToolLoopPattern, conversationId: UUID) {
        Self.logger.warning("""
        [ToolCallLoopDetection] 检测到工具调用循环：
        - 工具：\(pattern.toolName)
        - 调用次数：\(pattern.count)
        - 阈值：\(pattern.threshold)
        - 参数：\(truncated(pattern.toolArguments, limit: 100))
        """)

        let loopMessage = AgentChatMessage(
            role: .assistant,
            conversationId: conversationId,
            content: repeatedToolLoopMessage(
                toolName: pattern.toolName,
                repeatedCount: pattern.count,
                windowCount: pattern.count
            )
        )

        ToolCallLoopDetectionRuntimeBridge.saveMessage(loopMessage, conversationId)
        ToolCallLoopDetectionRuntimeBridge.markConversationCancelled(conversationId)
        ToolCallLoopDetectionRuntimeBridge.releaseConversationLock(conversationId)
        ToolCallLoopDetectionRuntimeBridge.setConversationStatus(
            conversationId,
            "检测到工具调用循环，已停止本轮"
        )
        ToolCallLoopDetectionRuntimeBridge.finishAgentTurn(conversationId, .failed("tool-call-loop"))
        ToolCallLoopDetectionRuntimeBridge.setTurnPhase(.idle, conversationId)
    }

    private static func repeatedToolLoopMessage(
        toolName: String,
        repeatedCount: Int,
        windowCount: Int
    ) -> String {
        switch LumiLanguagePreference.current {
        case .chinese:
            return "检测到工具调用可能进入循环：工具 `\(toolName)` 在最近 \(windowCount) 次窗口中重复调用 \(repeatedCount) 次。本轮已停止以避免继续重复执行。"
        case .english:
            return "Detected a possible tool-call loop: tool `\(toolName)` was called \(repeatedCount) times in the recent \(windowCount)-call window. This turn was stopped to avoid repeating the same action."
        }
    }

    private static func truncated(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)) + "..."
    }
}
