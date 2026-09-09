import Foundation
import ProviderConversation

/// Forwards typed selection events for the currently selected conversation.
///
/// `ConversationManaging` is passed around as a protocol existential, so a
/// view that only reads `selectedConversationID` cannot reliably invalidate
/// itself when the selection changes. This bridge turns the typed selection
/// callback into a small plugin-local event source.
@MainActor
final class ConversationSelectionBox {
    enum Event {
        case selectedConversationChanged(UUID?)
    }

    protocol ObserverHandle: AnyObject {
        func cancel()
    }

    private final class Handle: ObserverHandle {
        private let cancelAction: () -> Void
        private var isCancelled = false

        init(cancelAction: @escaping () -> Void) {
            self.cancelAction = cancelAction
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            cancelAction()
        }
    }

    private(set) var selectedConversationID: UUID?
    private var handle: (any SelectedConversationObserverHandle)?
    private var observers: [UUID: (Event) -> Void] = [:]

    init(conversations: any ConversationManaging) {
        selectedConversationID = conversations.selectedConversationID
        handle = conversations.addSelectedConversationObserver { [weak self] selectedID in
            self?.selectedConversationID = selectedID
            self?.notify(.selectedConversationChanged(selectedID))
        }
    }

    @discardableResult
    func addObserver(_ callback: @escaping (Event) -> Void) -> any ObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
        observers.removeAll()
    }

    private func notify(_ event: Event) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}
