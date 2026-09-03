import Foundation
import ProviderConversation

/// Observes the conversation events that can change the visible header title.
@MainActor
final class ConversationTitleHeaderObserver {
    private var handle: (any ConversationObserverHandle)?

    init(
        conversations: any ConversationManaging,
        onChange: @escaping () -> Void
    ) {
        onChange()
        handle = conversations.addConversationObserver { event in
            switch event {
            case .created, .listChanged, .selected, .deleted, .updated,
                 .markedActive, .providerChanged, .verbosityChanged,
                 .reasoningChanged, .automationChanged, .languageChanged:
                onChange()
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
