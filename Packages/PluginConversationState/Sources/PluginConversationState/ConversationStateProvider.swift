import Combine
import Foundation
import ProviderAgentLoop
import ProviderConversationState

/// 由插件持有的会话状态实现。
///
/// Provider 只负责保存、读取和更新状态；事件来源及其转换逻辑由
/// `Observers` 目录中的独立观察者负责。
@MainActor
public final class ConversationStateProvider: ConversationStateProviding {
    @Published public private(set) var states: [UUID: ConversationStateSnapshot] = [:]

    public init() {}

    public func state(for conversationID: UUID) -> ConversationStateSnapshot {
        states[conversationID] ?? ConversationStateSnapshot(conversationID: conversationID)
    }

    /// 合并指定会话的状态变化，并发布 `objectWillChange`。
    public func update(
        conversationID: UUID,
        turnID: UUID? = nil,
        agentLoopState: AgentLoopState? = nil,
        toolState: ConversationToolState? = nil,
        authorizationState: ConversationAuthorizationState? = nil,
        lastError: String? = nil,
        clearError: Bool = false
    ) {
        let current = state(for: conversationID)
        update(
            ConversationStateSnapshot(
                conversationID: conversationID,
                turnID: turnID ?? current.turnID,
                agentLoopState: agentLoopState ?? current.agentLoopState,
                toolState: toolState ?? current.toolState,
                authorizationState: authorizationState ?? current.authorizationState,
                lastError: clearError ? nil : (lastError ?? current.lastError)
            )
        )
    }

    /// 替换指定会话的完整状态快照。
    public func update(_ snapshot: ConversationStateSnapshot) {
        states[snapshot.conversationID] = snapshot
    }

    public func remove(conversationID: UUID) {
        states.removeValue(forKey: conversationID)
    }
}
