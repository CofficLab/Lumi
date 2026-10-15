import Combine
import Foundation
import ProviderConversationInput
import ProviderConversationInputBlock
import ProviderMessageSender

/// Bridges input and attachment provider changes into the input view model.
@MainActor
final class ConversationInputObserver {
    private weak var viewModel: ConversationInputViewModel?
    private var textHandle: (any TextInputObserverHandle)?
    private var blockHandle: (any ConversationInputBlockObserverHandle)?
    private var inputObserver: (any ConversationInputProvidingObserverHandle)?
    private var senderObserver: (any MessageSenderObserverHandle)?

    init(
        capability: any ConversationInputCapability,
        viewModel: ConversationInputViewModel
    ) {
        self.viewModel = viewModel
        viewModel.refresh()

        textHandle = capability.addTextObserver { [weak viewModel] _ in
            viewModel?.refresh()
        }
        blockHandle = capability.addBlockObserver { [weak viewModel] event in
            guard case let .blockSubmitted(block) = event else { return }
            viewModel?.enqueue(block)
        }
        inputObserver = capability.addInputObserver { [weak viewModel] event in
            guard case .errorMessageChanged = event else { return }
            viewModel?.refresh()
        }
        senderObserver = capability.addMessageSenderObserver { [weak viewModel] event in
            switch event {
            case .attachmentsChanged:
                viewModel?.refresh()
            case .started, .turnCompleted, .turnFailed, .pendingMessagesChanged:
                break
            }
        }
    }

    func cancel() {
        textHandle?.cancel()
        textHandle = nil
        blockHandle?.cancel()
        blockHandle = nil
        inputObserver = nil
        senderObserver = nil
        viewModel = nil
    }
}
