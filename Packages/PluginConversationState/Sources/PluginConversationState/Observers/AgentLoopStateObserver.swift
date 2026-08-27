import Foundation
import KitSuperLog
import os
import ProviderAgentLoop
import ProviderConversationState

/// 将 AgentLoop 生命周期事件转换为会话状态更新。
@MainActor
final class AgentLoopStateObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-state",
        category: "AgentLoopStateObserver"
    )

    private let provider: ConversationStateProvider
    private var handle: (any AgentLoopObserverHandle)?

    init(agentLoop: any AgentLoopProviding, provider: ConversationStateProvider) {
        self.provider = provider
        handle = agentLoop.addAgentLoopObserver { [weak self] event in
            self?.consume(event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }

    private func consume(_ event: AgentLoopEvent) {
        switch event {
        case .started(let id, let turn):
            provider.update(
                conversationID: id,
                turnID: turn,
                agentLoopState: .running,
                toolState: .idle,
                authorizationState: ConversationAuthorizationState.none,
                activity: .thinking,
                clearError: true
            )
        case .toolCallsReceived(let id, let turn, _, _):
            provider.update(conversationID: id, turnID: turn, agentLoopState: .running, toolState: .executing, activity: .executingTool)
        case .llmResponseReceived(let id, let turn, _):
            provider.update(conversationID: id, turnID: turn, agentLoopState: .running, activity: .thinking)
        case .suspended(let id, let turn, _):
            provider.update(conversationID: id, turnID: turn, agentLoopState: .suspended, toolState: .suspended)
        case .completed(let id, let turn):
            provider.update(
                conversationID: id,
                turnID: turn,
                agentLoopState: .completed,
                toolState: .completed,
                authorizationState: ConversationAuthorizationState.none,
                clearActivity: true
            )
        case .failed(let id, let turn, let reason):
            Self.logger.error("\(Self.t)AgentLoop failed conversation=\(id.uuidString, privacy: .public): \(reason, privacy: .public)")
            provider.update(
                conversationID: id,
                turnID: turn,
                agentLoopState: .failed,
                toolState: .completed,
                authorizationState: ConversationAuthorizationState.none,
                clearActivity: true,
                lastError: reason
            )
        case .cancelled(let id, let turn):
            provider.update(
                conversationID: id,
                turnID: turn,
                agentLoopState: .cancelled,
                toolState: .completed,
                authorizationState: ConversationAuthorizationState.none,
                clearActivity: true
            )
        }
    }
}
