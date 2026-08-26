import Foundation
import KitAgentTool
import KitSuperLog
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderToolManager

/// 消费 AgentLoop 发布的工具调用事件，并将工具执行结果交给 ToolManager。
@MainActor
final class AgentLoopToolCallsObserver: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.tool-manager", category: "AgentLoopToolCallsObserver")
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose = true

    private let service: ToolManager
    private let conversations: any ConversationManaging
    private var agentLoopObserver: (any AgentLoopObserverHandle)?

    init(
        agentLoop: any AgentLoopProviding,
        conversations: any ConversationManaging,
        service: ToolManager
    ) {
        self.service = service
        self.conversations = conversations
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
        switch conversations.automationLevel(for: conversationID) {
        case .chat:
            policy = .blockAll
        case .autonomous:
            policy = .autoExecute
        case .build:
            policy = .requireApprovalForHighRisk
        }

        let inputs = toolCalls.map { ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) }
        if Self.verbose {
            Self.logger.info("\(Self.t)收到 AgentLoop 工具调用事件 conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID.uuidString.prefix(8)), count=\(inputs.count)")
        }

        Task { @MainActor [weak self] in
            guard let self else {
                Self.logger.error("\(Self.emoji)ToolManager 工具调用观察者已释放，无法执行工具批次")
                return
            }
            _ = await self.service.executeBatch(
                inputs,
                policy: policy,
                conversationID: conversationID,
                turnID: turnID
            )
        }
    }
}
