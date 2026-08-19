import AgentToolKit
import Combine
import Foundation
import KitLLM
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import SuperLogKit

/// Agent 回合执行器门面（Facade）。
///
/// 职责仅限三件事：
/// - 依赖注入（构造注入 `MessageManaging`，`setXxx` 注入其余 service）；
/// - 把 `AgentLoopProviding` 的公共 API 转发给 `AgentLoopTurnManager`；
/// - 发布 `revision`（宿主观察状态变化的信号，Manager 状态变更时递增）。
///
/// 回合运行的全部逻辑（runTurn / resumeTurn / executeTurnLoop、工具执行、
/// 授权挂起/恢复、未完成批次续跑）由 `Managers/AgentLoopTurnManager` 承担；
/// 后续新增 Manager（工具执行、消息准备等）同样放入 `Managers/` 目录，
/// 由本门面统一转发，保持关注点分离。
@MainActor
public final class AgentLoopProvider: AgentLoopProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-loop")
    public nonisolated static let emoji = "🔄"
    public static let verbose = true

    private let turnManager: TurnManager

    @Published public internal(set) var revision: Int = 0

    init(
        messages: any MessageManaging,
        llmManager: any LLMManaging,
        toolManager: any ToolManagerProviding,
        streaming: any MessageStreamingProviding,
        conversations: any ConversationManaging
    ) {
        self.turnManager = TurnManager(
            messages: messages,
            llmManager: llmManager,
            toolManager: toolManager,
            streaming: streaming,
            conversations: conversations
        )
        self.turnManager.onRevisionChange = { [weak self] in
            self?.revision += 1
        }
    }

    // MARK: - Injection

    public func setResponder(_ responder: AgentLoopResponder?) {
        turnManager.setResponder(responder)
    }

    public func setEventHandler(_ handler: AgentLoopEventHandler?) {
        turnManager.setEventHandler(handler)
    }

    // MARK: - AgentLoopProviding

    public func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        try await turnManager.runTurn(in: conversationID)
    }

    public func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        try await turnManager.resumeTurn(in: conversationID, request: request)
    }

    public func cancelTurn(in conversationID: UUID) {
        turnManager.cancelTurn(in: conversationID)
    }

    public func state(for conversationID: UUID) -> AgentLoopState {
        turnManager.state(for: conversationID)
    }

    public func isRunning(for conversationID: UUID) -> Bool {
        turnManager.isRunning(for: conversationID)
    }

    public func suspension(for conversationID: UUID) -> AgentLoopSuspension? {
        turnManager.suspension(for: conversationID)
    }

    public func currentTurnID(for conversationID: UUID) -> UUID? {
        turnManager.currentTurnID(for: conversationID)
    }

    // MARK: - 兼容旧 API

    public func createTurn(_ request: AgentTurnRequest) async throws -> AgentTurnHandle {
        turnManager.createTurn(request)
        return AgentTurnHandle()
    }
}
