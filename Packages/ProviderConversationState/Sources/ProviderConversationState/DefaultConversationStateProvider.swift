import Combine
import Foundation
import ProviderAgentLoop
import ProviderToolManager

/// 只观察 AgentLoop 和 ToolManager，并维护会话状态快照。
@MainActor
public final class DefaultConversationStateProvider: ConversationStateProviding {
    @Published public private(set) var states: [UUID: ConversationStateSnapshot] = [:]

    private var agentLoopObserver: (any AgentLoopObserverHandle)?
    private var toolManagerObserver: (any ToolManagerObserverHandle)?

    public init(agentLoop: any AgentLoopProviding, toolManager: any ToolManagerProviding) {
        agentLoopObserver = agentLoop.addAgentLoopObserver { [weak self] event in
            self?.consume(event)
        }
        toolManagerObserver = toolManager.addToolManagerObserver { [weak self] event in
            self?.consume(event)
        }
    }

    public func state(for conversationID: UUID) -> ConversationStateSnapshot {
        states[conversationID] ?? ConversationStateSnapshot(conversationID: conversationID)
    }

    private func consume(_ event: AgentLoopEvent) {
        switch event {
        case .started(let conversationID, let turnID):
            update(conversationID, turnID: turnID, agentLoopState: .running, toolState: .idle, clearError: true)
        case .toolCallsReceived(let conversationID, let turnID, _, _),
             .llmResponseReceived(let conversationID, let turnID, _):
            update(conversationID, turnID: turnID, agentLoopState: .running, toolState: .executing)
        case .suspended(let conversationID, let turnID, _):
            update(conversationID, turnID: turnID, agentLoopState: .suspended, toolState: .suspended)
        case .completed(let conversationID, let turnID):
            update(conversationID, turnID: turnID, agentLoopState: .completed, toolState: .completed)
        case .failed(let conversationID, let turnID, let reason):
            update(conversationID, turnID: turnID, agentLoopState: .failed, toolState: .completed, lastError: reason)
        case .cancelled(let conversationID, let turnID):
            update(conversationID, turnID: turnID, agentLoopState: .cancelled, toolState: .completed)
        }
    }

    private func consume(_ event: ToolManagerEvent) {
        switch event {
        case .started(let conversationID, let turnID, _):
            update(conversationID, turnID: turnID, toolState: .executing)
        case .completed(let conversationID, let turnID, _, _),
             .authorizedCompleted(let conversationID, let turnID, _, _):
            update(conversationID, turnID: turnID, toolState: .completed)
        case .batchCompleted(let conversationID, let turnID, _, _):
            update(conversationID, turnID: turnID, toolState: .completed)
        }
    }

    private func update(
        _ conversationID: UUID,
        turnID: UUID? = nil,
        agentLoopState: AgentLoopState? = nil,
        toolState: ConversationToolState? = nil,
        lastError: String? = nil,
        clearError: Bool = false
    ) {
        let current = state(for: conversationID)
        states[conversationID] = ConversationStateSnapshot(
            conversationID: conversationID,
            turnID: turnID ?? current.turnID,
            agentLoopState: agentLoopState ?? current.agentLoopState,
            toolState: toolState ?? current.toolState,
            lastError: clearError ? nil : (lastError ?? current.lastError)
        )
    }
}
