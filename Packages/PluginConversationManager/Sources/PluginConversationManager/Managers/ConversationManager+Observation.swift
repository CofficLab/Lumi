import Foundation
import ProviderConversation

@MainActor
final class ConversationObserverHandleImpl: ConversationObserverHandle {
    private weak var owner: ConversationManager?
    private let callback: (ConversationEvent) -> Void
    private var isCancelled = false

    init(owner: ConversationManager, callback: @escaping (ConversationEvent) -> Void) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.removeConversationObserver(self)
    }

    fileprivate func invoke(_ event: ConversationEvent) {
        guard !isCancelled else { return }
        callback(event)
    }
}

@MainActor
final class WeakConversationObserver {
    weak var handle: ConversationObserverHandleImpl?

    init(_ handle: ConversationObserverHandleImpl) {
        self.handle = handle
    }
}
