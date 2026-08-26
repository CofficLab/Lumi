import Foundation
import KitSuperLog
import os
import ProviderAgentLoop
import ProviderToolManager

/// 消费 ToolManager 的执行结果事件，并推进 AgentLoop 回合。
@MainActor
final class ToolManagerObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.agent-loop.tool-manager-observer"
    )
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose = true

    private weak var agentLoop: (any AgentLoopProviding)?
    private var toolManagerObserver: (any ToolManagerObserverHandle)?

    init(toolManager: any ToolManagerProviding, agentLoop: any AgentLoopProviding) {
        self.agentLoop = agentLoop
        self.toolManagerObserver = toolManager.addToolManagerObserver { [weak self] event in
            self?.handle(event)
        }
    }

    func cancel() {
        toolManagerObserver?.cancel()
        toolManagerObserver = nil
    }

    private func handle(_ event: ToolManagerEvent) {
        guard let agentLoop else {
            Self.logger.error("\(Self.emoji)无法处理 ToolManager 事件：AgentLoopProvider 已释放")
            return
        }
        if case let .batchCompleted(conversationID, turnID, _, results) = event,
           Self.verbose {
            Self.logger.info(
                "\(Self.t)🍋 tool batch event received conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID?.uuidString.prefix(8) ?? "nil"), results=\(results.count)"
            )
        }

        // ToolManager 事件已经在 MainActor 上分发，直接推进回合状态机，
        // 避免批次完成后再异步调度导致下一轮请求被延迟或丢失。
        guard let agentLoop = agentLoop as? AgentLoopManager else {
            Self.logger.error("\(Self.emoji)无法处理 ToolManager 事件：AgentLoopProvider 不是 AgentLoopManager")
            return
        }
        agentLoop.handleToolManagerEvent(event)
    }
}
