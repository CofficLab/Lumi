import Combine
import ProviderConversation
import SwiftUI

/// Bridges conversation-manager changes to SwiftUI for the toolbar.
@MainActor
final class ConversationManagerObservationBox: ObservableObject {
    let conversations: any ConversationManaging
    @Published private(set) var revision = 0
    private var cancellable: AnyCancellable?

    init(conversations: any ConversationManaging) {
        self.conversations = conversations
        cancellable = conversations.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
            .sink { [weak self] _ in
                self?.revision += 1
            }
    }

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}
