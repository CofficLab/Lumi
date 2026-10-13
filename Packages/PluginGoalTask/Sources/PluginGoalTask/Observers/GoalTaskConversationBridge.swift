import Combine
import Foundation
import ProviderConversation

/// Bridges selected-conversation events into the Goal Task UI state.
@MainActor
final class GoalTaskConversationBridge: ObservableObject {
    @Published var selectedConversationID: UUID?
    private var handle: (any SelectedConversationObserverHandle)?

    init(_ conversations: any ConversationManaging) {
        selectedConversationID = conversations.selectedConversationID
        handle = conversations.addSelectedConversationObserver { [weak self] newID in
            self?.selectedConversationID = newID
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
