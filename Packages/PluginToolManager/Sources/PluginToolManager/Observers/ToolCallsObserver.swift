import Foundation
import KitAgentTool
import KitSuperLog
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderToolManager

/// 消费 AgentLoop 发布的工具调用事件，并将工具执行结果交给 ToolManager。
@MainActor
final class ToolCallsObserver: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.tool-manager", category: "AgentLoopToolCallsObserver")
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose = true

    private let toolManager: ToolManager
    private let conversationManager: any ConversationManaging
    private var agentLoopObserver: (any AgentLoopObserverHandle)?

    init(
        agentLoop: any AgentLoopProviding,
        conversations: any ConversationManaging,
        service: ToolManager
    ) {
        self.toolManager = service
        self.conversationManager = conversations
        self.agentLoopObserver = agentLoop.addAgentLoopObserver { [weak self] event in
            self?.handle(event)
        }
    }

    func cancel() {
        agentLoopObserver?.cancel()
        agentLoopObserver = nil
    }

    private func handle(_ event: AgentLoopEvent) {
        guard case let .toolCallsReceived(conversationID, turnID, _, toolCalls) = event else {
            return
        }
        guard !toolCalls.isEmpty else { return }

        let policy: ToolExecutionPolicy
        switch conversationManager.automationLevel(for: conversationID) {
        case .chat:
            policy = .blockAll
        case .autonomous:
            policy = .autoExecute
        case .build:
            policy = .requireApprovalForHighRisk
        }

        let inputs = toolCalls.map { ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) }
        let executableInputs: [ToolCall]
        let executionPolicy: ToolExecutionPolicy
        switch policy {
        case .blockAll:
            // Chat 模式需要发布 blocked 结果，让 AgentLoop 正常结束当前工具步骤。
            executableInputs = inputs
            executionPolicy = .blockAll
        case .autoExecute, .requireApprovalForHighRisk:
            executableInputs = inputs.filter { toolCall in
                let risk = toolManager.riskLevel(for: toolCall) ?? .high
                guard !risk.requiresPermission else {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)工具需要授权，Observer 放弃执行 tool=\(toolCall.name), id=\(toolCall.id), risk=\(risk.rawValue)")
                    }
                    return false
                }
                return true
            }
            executionPolicy = .autoExecute
        }

        guard !executableInputs.isEmpty else { return }
        if Self.verbose {
            Self.logger.info("\(Self.t)收到 AgentLoop 工具调用事件 conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8)), count=\(executableInputs.count)")
        }

        Task { @MainActor [weak self] in
            guard let self else {
                Self.logger.error("\(Self.emoji)ToolManager 工具调用观察者已释放，无法执行工具批次")
                return
            }
            _ = await self.toolManager.executeBatch(
                executableInputs,
                policy: executionPolicy,
                conversationID: conversationID,
                turnID: turnID
            )
        }
    }
}
