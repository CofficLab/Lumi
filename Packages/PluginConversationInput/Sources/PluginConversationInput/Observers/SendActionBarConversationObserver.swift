import Foundation
import ProviderConversation
import ProviderConversationState

/// Observes selected-conversation and conversation-state changes for the send bar.
///
/// Events directly refresh the view model; no onChange callback escapes the observer.
@MainActor
final class SendActionBarConversationObserver {
    private weak var viewModel: SendActionBarViewModel?
    private var stateHandle: (any ConversationStateObserverHandle)?
    private var conversationHandle: (any SelectedConversationObserverHandle)?

    init(
        capability: any ConversationInputCapability,
        viewModel: SendActionBarViewModel
    ) {
        self.viewModel = viewModel
        stateHandle = capability.addConversationStateObserver { [weak viewModel] _ in
            viewModel?.refreshConversationState()
        }
        conversationHandle = capability.addSelectedConversationObserver { [weak viewModel] _ in
            viewModel?.refreshConversationState()
        }
    }

    func cancel() {
        stateHandle?.cancel()
        stateHandle = nil
        conversationHandle?.cancel()
        conversationHandle = nil
        viewModel = nil
    }
}
