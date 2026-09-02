import Combine
import Foundation
import KitSuperLog
import os
import ProviderAgentLoop
import ProviderConversationState

/// 由插件持有的会话状态实现。
///
/// Provider 只负责保存、读取和更新状态；事件来源及其转换逻辑由
/// `Observers` 目录中的独立观察者负责。
@MainActor
public final class ConversationStateProvider: ConversationStateProviding, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-state",
        category: "Provider"
    )
    nonisolated public static let emoji = "📋"
    nonisolated public static let verbose = false

    @Published public private(set) var states: [UUID: ConversationStateSnapshot] = [:]
    private var observers: [UUID: Observer] = [:]

    public init() {
        if Self.verbose {
            Self.logger.debug("\(Self.t)initialized")
        }
    }

    @discardableResult
    public func addConversationStateObserver(
        _ callback: @escaping (ConversationStateEvent) -> Void
    ) -> any ConversationStateObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers[observer.id] = observer
        return observer
    }

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
        activity: ConversationActivity? = nil,
        jobActivity: ConversationJobActivity? = nil,
        clearActivity: Bool = false,
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
                activity: clearActivity ? nil : (activity ?? current.activity),
                jobActivity: jobActivity ?? current.jobActivity,
                lastError: clearError ? nil : (lastError ?? current.lastError)
            )
        )
    }

    /// 替换指定会话的完整状态快照。
    public func update(_ snapshot: ConversationStateSnapshot) {
        states[snapshot.conversationID] = snapshot
        notify(.updated(snapshot.conversationID))
        if Self.verbose {
            let turn = snapshot.turnID?.uuidString ?? "nil"
            let error = snapshot.lastError ?? "nil"
            let stateDescription = [
                "conversation=\(snapshot.conversationID.uuidString)",
                "turn=\(turn)",
                "agentLoop=\(snapshot.agentLoopState.rawValue)",
                "tool=\(snapshot.toolState.rawValue)",
                "authorization=\(snapshot.authorizationState.rawValue)",
                "activity=\(snapshot.activity?.rawValue ?? "none")",
                "jobs=\(snapshot.jobActivity.currentJobCount)/\(snapshot.jobActivity.runningJobCount)",
                "isSending=\(snapshot.isSending)",
                "error=\(error)",
            ].joined(separator: ", ")
            Self.logger.debug("\(Self.t)Conversation state updated: \(stateDescription)")
        }
    }

    public func remove(conversationID: UUID) {
        guard states.removeValue(forKey: conversationID) != nil else { return }
        notify(.removed(conversationID))
        if Self.verbose {
            Self.logger.debug("\(Self.t)Conversation state removed")
        }
    }

    private func notify(_ event: ConversationStateEvent) {
        observers.values.forEach { $0.invoke(event) }
    }

    private func removeObserver(id: UUID) {
        observers.removeValue(forKey: id)
    }

    private final class Observer: ConversationStateObserverHandle {
        let id = UUID()
        private weak var owner: ConversationStateProvider?
        private let callback: (ConversationStateEvent) -> Void
        private var isCancelled = false

        init(owner: ConversationStateProvider, callback: @escaping (ConversationStateEvent) -> Void) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            owner?.removeObserver(id: id)
        }

        func invoke(_ event: ConversationStateEvent) {
            guard !isCancelled else { return }
            callback(event)
        }

    }
}
