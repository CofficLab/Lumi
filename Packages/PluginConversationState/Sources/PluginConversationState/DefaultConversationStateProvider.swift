import Combine
import Foundation
import KernelCore
import KitSuperLog
import ProviderAgentLoop
import ProviderConversationState
import ProviderToolManager

/// 由插件持有的会话状态实现。
///
/// Provider 包只定义能力契约；事件订阅和状态维护属于本插件的运行时职责。
@MainActor
public final class DefaultConversationStateProvider: ConversationStateProviding, SuperLog {
    public nonisolated static let emoji = "📋"

    @Published public private(set) var states: [UUID: ConversationStateSnapshot] = [:]

    private var agentLoopObserver: (any AgentLoopObserverHandle)?
    private var toolManagerObserver: (any ToolManagerObserverHandle)?

    public init(agentLoop: any AgentLoopProviding, toolManager: any ToolManagerProviding) {
        print(Self.i)
        agentLoopObserver = agentLoop.addAgentLoopObserver { [weak self] event in self?.consume(event) }
        toolManagerObserver = toolManager.addToolManagerObserver { [weak self] event in self?.consume(event) }
    }

    public func state(for conversationID: UUID) -> ConversationStateSnapshot {
        states[conversationID] ?? ConversationStateSnapshot(conversationID: conversationID)
    }

    private func consume(_ event: AgentLoopEvent) {
        switch event {
        case .started(let id, let turn):
            print("\(t)AgentLoop started conversation=\(id) turn=\(turn)")
            update(id, turnID: turn, agentLoopState: .running, toolState: .idle, authorizationState: ConversationAuthorizationState.none, clearError: true)
        case .toolCallsReceived(let id, let turn, _, _):
            print("\(t)AgentLoop toolCallsReceived conversation=\(id) turn=\(turn)")
            update(id, turnID: turn, agentLoopState: .running, toolState: .executing)
        case .llmResponseReceived(let id, let turn, _):
            print("\(t)AgentLoop llmResponseReceived conversation=\(id) turn=\(turn)")
            update(id, turnID: turn, agentLoopState: .running, toolState: .executing)
        case .suspended(let id, let turn, _):
            print("\(t)AgentLoop suspended conversation=\(id) turn=\(turn)")
            update(id, turnID: turn, agentLoopState: .suspended, toolState: .suspended)
        case .completed(let id, let turn):
            print("\(t)AgentLoop completed conversation=\(id) turn=\(turn)")
            update(id, turnID: turn, agentLoopState: .completed, toolState: .completed, authorizationState: ConversationAuthorizationState.none)
        case .failed(let id, let turn, let reason):
            print("\(t)AgentLoop failed conversation=\(id) turn=\(turn)\(r(reason))")
            update(id, turnID: turn, agentLoopState: .failed, toolState: .completed, authorizationState: ConversationAuthorizationState.none, lastError: reason)
        case .cancelled(let id, let turn):
            print("\(t)AgentLoop cancelled conversation=\(id) turn=\(String(describing: turn))")
            update(id, turnID: turn, agentLoopState: .cancelled, toolState: .completed, authorizationState: ConversationAuthorizationState.none)
        }
    }

    private func consume(_ event: ToolManagerEvent) {
        switch event {
        case .started(let id, let turn, _):
            print("\(t)ToolManager started conversation=\(id) turn=\(String(describing: turn))")
            update(id, turnID: turn, toolState: .executing)
        case .authorizationRequired(let id, let turn, _):
            print("\(t)ToolManager authorizationRequired conversation=\(id) turn=\(String(describing: turn))")
            update(id, turnID: turn, authorizationState: .required)
        case .completed(let id, let turn, _, _):
            print("\(t)ToolManager completed conversation=\(id) turn=\(String(describing: turn))")
            update(id, turnID: turn, toolState: .completed)
        case .authorizedCompleted(let id, let turn, _, _):
            print("\(t)ToolManager authorizedCompleted conversation=\(id) turn=\(String(describing: turn))")
            update(id, turnID: turn, toolState: .completed, authorizationState: ConversationAuthorizationState.none)
        case .batchCompleted(let id, let turn, _, _):
            print("\(t)ToolManager batchCompleted conversation=\(id) turn=\(String(describing: turn))")
            update(id, turnID: turn, toolState: .completed)
        }
    }

    private func update(_ id: UUID, turnID: UUID? = nil, agentLoopState: AgentLoopState? = nil, toolState: ConversationToolState? = nil, authorizationState: ConversationAuthorizationState? = nil, lastError: String? = nil, clearError: Bool = false) {
        let current = state(for: id)
        states[id] = ConversationStateSnapshot(
            conversationID: id,
            turnID: turnID ?? current.turnID,
            agentLoopState: agentLoopState ?? current.agentLoopState,
            toolState: toolState ?? current.toolState,
            authorizationState: authorizationState ?? current.authorizationState,
            lastError: clearError ? nil : (lastError ?? current.lastError)
        )
    }
}
