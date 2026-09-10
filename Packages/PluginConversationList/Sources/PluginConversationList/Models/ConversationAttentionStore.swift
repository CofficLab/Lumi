import Foundation

/// Tracks conversations whose agent turn finished while they were not selected.
@MainActor
public final class ConversationAttentionStore {
    public enum Event {
        case attentionChanged(conversationID: UUID, needsAttention: Bool)
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

    private var conversationIDs: Set<UUID> = []
    private var observers: [UUID: (Event) -> Void] = [:]

    public init() {}

    @discardableResult
    public func addObserver(_ callback: @escaping (Event) -> Void) -> any ObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    public func markNeedsAttention(conversationID: UUID) {
        guard conversationIDs.insert(conversationID).inserted else { return }
        notify(.attentionChanged(conversationID: conversationID, needsAttention: true))
    }

    public func markRead(conversationID: UUID) {
        guard conversationIDs.remove(conversationID) != nil else { return }
        notify(.attentionChanged(conversationID: conversationID, needsAttention: false))
    }

    public func needsAttention(for conversationID: UUID) -> Bool {
        conversationIDs.contains(conversationID)
    }

    private func notify(_ event: Event) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}
