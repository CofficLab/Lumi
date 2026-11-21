import Foundation
import KitAgentTool
import LumiLoggingKit
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
            // A3 完全授权：所有工具直接提交执行，不弹授权。工具自身声明的
            // 强制确认（如 run_command 的 unsandboxed、mail_send_message）
            // 在这里同样放行——A3 语义就是"充分授权"。
            _ = toolManager.submit(
                inputs,
                policy: .autoExecute,
                conversationID: conversationID,
                turnID: turnID
            )
        case .requireApprovalForHighRisk:
            // 整批按模型给定的顺序交给 executeBatch：免授权调用依次执行，
            // 遇到第一个需要授权的调用即暂停，其后所有调用（包括免授权的）
            // 都必须等用户决定（#149）。此前按授权类型分桶再分别提交，会把
            // 暂停点之后的免授权调用提前执行，破坏批次契约。
            executeLegacyBatch(
                inputs,
                policy: .requireApprovalForHighRisk,
                conversationID: conversationID,
                turnID: turnID
            )
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
