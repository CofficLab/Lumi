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
    nonisolated static let verbose = false

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
        switch policy {
        case .blockAll:
            // Chat 模式仍使用兼容事件发布 blocked 结果；executeBatch 对该策略
            // 不会执行工具，因此把它放进 Task 不会阻塞当前 AgentLoop 回调。
            executeLegacyBatch(inputs, policy: .blockAll, conversationID: conversationID, turnID: turnID)
        case .autoExecute:
            // Job manager 只负责提交和启动后台任务，绝不在这里等待工具结果。
            _ = toolManager.submit(
                inputs,
                policy: .autoExecute,
                conversationID: conversationID,
                turnID: turnID
            )
        case .requireApprovalForHighRisk:
            var autoExecutableInputs: [ToolCall] = []
            var approvalInputs: [ToolCall] = []
            var blockedInputs: [ToolCall] = []
            for toolCall in inputs {
                switch toolManager.authorizationDecision(
                    for: toolCall,
                    conversationID: conversationID
                ) {
                case .autoApproved:
                    autoExecutableInputs.append(toolCall)
                case .requiresUserApproval:
                    approvalInputs.append(toolCall)
                    if Self.verbose {
                        Self.logger.info("\(Self.t)🌚 工具需要授权，暂停执行 tool=\(toolCall.name), id=\(toolCall.id)")
                    }
                case .blocked:
                    // build 模式通常不会返回 blocked，但自定义授权策略可能会；
                    // 单独走 blockAll，避免被 requireApproval 的兼容逻辑误执行。
                    blockedInputs.append(toolCall)
                }
            }

            if !autoExecutableInputs.isEmpty {
                _ = toolManager.submit(
                    autoExecutableInputs,
                    policy: .autoExecute,
                    conversationID: conversationID,
                    turnID: turnID
                )
            }
            if !blockedInputs.isEmpty {
                executeLegacyBatch(
                    blockedInputs,
                    policy: .blockAll,
                    conversationID: conversationID,
                    turnID: turnID
                )
            }
            if !approvalInputs.isEmpty {
                executeLegacyBatch(
                    approvalInputs,
                    policy: .requireApprovalForHighRisk,
                    conversationID: conversationID,
                    turnID: turnID
                )
            }
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)🍋 收到 AgentLoop 工具调用事件 conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8)), count=\(inputs.count)")
        }
    }

    private func executeLegacyBatch(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID
    ) {
        Task { @MainActor [weak self] in
            guard let self else {
                Self.logger.error("\(Self.emoji)ToolManager 工具调用观察者已释放，无法执行工具批次")
                return
            }
            _ = await self.toolManager.executeBatch(
                toolCalls,
                policy: policy,
                conversationID: conversationID,
                turnID: turnID
            )
        }
    }
}
