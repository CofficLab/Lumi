import Foundation

/// Typed, plugin-local change channel for Goal Task mutations.
@MainActor
final class GoalChangeCenter {
    static let shared = GoalChangeCenter()

    private var callbacks: [UUID: (UUID) -> Void] = [:]

    @discardableResult
    func addObserver(_ callback: @escaping (UUID) -> Void) -> GoalChangeToken {
        let id = UUID()
        callbacks[id] = callback
        return GoalChangeToken { [weak self] in
            self?.callbacks[id] = nil
        }
    }

    func notify(conversationID: UUID) {
        callbacks.values.forEach { $0(conversationID) }
    }
}

@MainActor
final class GoalChangeToken {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }

}

/// Observes goal-change notifications emitted by Goal Task tools.
@MainActor
final class GoalChangeObserver {
    private var token: GoalChangeToken?

    init(onChange: @escaping (UUID) -> Void) {
        token = GoalChangeCenter.shared.addObserver(onChange)
    }

    func cancel() {
        token?.cancel()
        token = nil
    }
}
