import Foundation

/// A typed, plugin-local change channel for mutations made by Story Writer tools.
@MainActor
final class StoryWriterChangeCenter {
    static let shared = StoryWriterChangeCenter()

    private var callbacks: [UUID: () -> Void] = [:]

    @discardableResult
    func addObserver(_ callback: @escaping () -> Void) -> StoryWriterChangeToken {
        let id = UUID()
        callbacks[id] = callback
        return StoryWriterChangeToken { [weak self] in
            self?.callbacks[id] = nil
        }
    }

    func notify() {
        callbacks.values.forEach { $0() }
    }
}

@MainActor
final class StoryWriterChangeToken {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }

}

/// Observes store-change broadcasts emitted by Story Writer tools.
@MainActor
final class StoryWriterChangeObserver {
    private var token: StoryWriterChangeToken?

    init(onChange: @escaping () -> Void) {
        token = StoryWriterChangeCenter.shared.addObserver(onChange)
    }

    func cancel() {
        token?.cancel()
        token = nil
    }
}
