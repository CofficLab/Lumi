import Foundation
import ProviderMessageSender

/// Forwards pending-message events from the type-erased message sender.
@MainActor
public final class MessageSendingBox {
    public enum Event {
        case pendingMessagesChanged(conversationID: UUID)
    }

    public protocol ObserverHandle: AnyObject {
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

    public let sender: any MessageSendingProviding
    private var senderObserver: (any MessageSenderObserverHandle)?
    private var observers: [UUID: (Event) -> Void] = [:]

    public init(sender: any MessageSendingProviding) {
        self.sender = sender
        senderObserver = sender.addMessageSenderObserver { [weak self] event in
            switch event {
            case let .pendingMessagesChanged(conversationID):
                self?.notify(.pendingMessagesChanged(conversationID: conversationID))
            case .started, .turnCompleted, .turnFailed, .attachmentsChanged:
                break
            }
        }
    }

    @discardableResult
    public func addObserver(_ callback: @escaping (Event) -> Void) -> any ObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func cancel() {
        senderObserver?.cancel()
        senderObserver = nil
        observers.removeAll()
    }

    private func notify(_ event: Event) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}
