import ProviderConversation
import SwiftUI

/// Bridges conversation-manager changes to SwiftUI for the toolbar.
@MainActor
final class ConversationManagerObservationBox: ObservableObject {
    let conversations: any ConversationManaging
    @Published private(set) var revision = 0
    private var observer: (any ConversationObserverHandle)?

    init(conversations: any ConversationManaging) {
        self.conversations = conversations
        observer = conversations.addConversationObserver { [weak self] _ in
            self?.revision += 1
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }
}
