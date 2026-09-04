import Combine
import Foundation
import ProviderConversation
import SwiftUI

/// SwiftUI bridge for the currently selected conversation.
///
/// `ConversationManaging` is passed around as a protocol existential, so a
/// view that only reads `selectedConversationID` cannot reliably invalidate
/// itself when the selection changes. This bridge turns the typed selection
/// callback into observable state owned by the pending-message plugin.
@MainActor
final class ObservableConversationSelectionBox: ObservableObject {
    @Published private(set) var selectedConversationID: UUID?
    private var handle: (any SelectedConversationObserverHandle)?

    init(conversations: any ConversationManaging) {
        selectedConversationID = conversations.selectedConversationID
        handle = conversations.addSelectedConversationObserver { [weak self] selectedID in
            self?.selectedConversationID = selectedID
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
