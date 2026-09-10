import Foundation
import ProviderConversationState
import ProviderMessageStreaming

/// 将会话活动状态变化转发给消息列表 VM。
@MainActor
final class ConversationStateObserver {
    private weak var stateVM: ConversationStateVM?
    private let state: any ConversationStateProviding
    private let streaming: (any MessageStreamingProviding)?
    private var stateHandle: (any ConversationStateObserverHandle)?
    private var streamingHandle: (any MessageStreamingObserverHandle)?
    private var selectedConversationID: UUID?
    private var conversationState: ConversationStateSnapshot?
    private var streamingStage: MessageStreamingStage = .idle

    init(
        state: any ConversationStateProviding,
        streaming: (any MessageStreamingProviding)?,
        conversationID: UUID?,
        stateVM: ConversationStateVM
    ) {
        self.state = state
        self.streaming = streaming
        self.stateVM = stateVM
        updateSelectedConversation(conversationID)
        stateHandle = state.addConversationStateObserver { [weak self] change in
            self?.handleStateChange(change)
        }
        streamingHandle = streaming?.addMessageStreamingObserver { [weak self] change in
            self?.handleStreamingChange(change)
        }
    }

    func updateSelectedConversation(_ conversationID: UUID?) {
        guard selectedConversationID != conversationID else { return }
        selectedConversationID = conversationID
        conversationState = nil
        streamingStage = .idle
        stateVM?.updateSelectedConversation(conversationID)

        guard let conversationID else { return }
        conversationState = state.state(for: conversationID)
        streamingStage = streaming?.stage(for: conversationID) ?? .idle
        publish(for: conversationID)
    }

    func cancel() {
        stateHandle?.cancel()
        stateHandle = nil
        streamingHandle?.cancel()
        streamingHandle = nil
    }

    private func handleStateChange(_ change: ConversationStateEvent) {
        let conversationID: UUID
        switch change {
        case let .updated(id):
            guard id == selectedConversationID else { return }
            conversationID = id
            conversationState = state.state(for: id)
        case let .removed(id):
            guard id == selectedConversationID else { return }
            conversationID = id
            conversationState = nil
        }
        publish(for: conversationID)
    }

    private func handleStreamingChange(_ change: MessageStreamingChange) {
        guard case let .updated(conversationID) = change else { return }
        guard conversationID == selectedConversationID else { return }
        streamingStage = streaming?.stage(for: conversationID) ?? .idle
        publish(for: conversationID)
    }

    private func publish(for conversationID: UUID) {
        let activity = AgentActivityProjection.resolve(
            conversationState: conversationState,
            streamingStage: streamingStage
        )
        stateVM?.update(activity: activity, for: conversationID)
    }
}
