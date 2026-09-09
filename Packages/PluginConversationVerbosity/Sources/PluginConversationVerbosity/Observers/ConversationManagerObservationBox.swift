import Foundation
import ProviderConversation

/// Forwards relevant conversation-manager typed events to the toolbar view.
@MainActor
final class ConversationManagerObservationBox {
    enum Event {
        case conversationChanged(ConversationEvent)
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

    let capability: any ConversationVerbosityCapability
    private var conversationObserver: (any ConversationObserverHandle)?
    private var observers: [UUID: (Event) -> Void] = [:]

    init(capability: any ConversationVerbosityCapability) {
        self.capability = capability
        conversationObserver = capability.addConversationObserver { [weak self] event in
            // Refresh UI on verbosity changes, selection changes, or structural changes.
            switch event {
            case .verbosityChanged, .selected, .created, .deleted, .listChanged:
                self?.notify(.conversationChanged(event))
            default:
                break
            }
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
        conversationObserver?.cancel()
        conversationObserver = nil
        observers.removeAll()
    }

    private func notify(_ event: Event) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}
