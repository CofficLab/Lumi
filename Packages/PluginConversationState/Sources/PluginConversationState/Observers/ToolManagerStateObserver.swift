import Foundation
import KitSuperLog
import os
import ProviderConversationState
import ProviderToolManager

/// 将 ToolManager 生命周期和授权事件转换为会话状态更新。
@MainActor
final class ToolManagerStateObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-state",
        category: "ToolManagerStateObserver"
    )

    private let provider: ConversationStateProvider
    private var handle: (any ToolManagerObserverHandle)?

    init(toolManager: any ToolManagerProviding, provider: ConversationStateProvider) {
        self.provider = provider
        handle = toolManager.addToolManagerObserver { [weak self] event in
            self?.consume(event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }

    private func consume(_ event: ToolManagerEvent) {
        switch event {
        case .started(let id, let turn, _):
            provider.update(conversationID: id, turnID: turn, toolState: .executing)
        case .authorizationRequired(let id, let turn, _):
            provider.update(conversationID: id, turnID: turn, authorizationState: .required)
        case .completed(let id, let turn, _, _),
             .batchCompleted(let id, let turn, _, _):
            provider.update(conversationID: id, turnID: turn, toolState: .completed)
        case .authorizedCompleted(let id, let turn, _, _):
            provider.update(
                conversationID: id,
                turnID: turn,
                toolState: .completed,
                authorizationState: ConversationAuthorizationState.none
            )
        }
    }
}
