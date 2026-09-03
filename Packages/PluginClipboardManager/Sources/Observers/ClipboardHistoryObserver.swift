import Foundation

/// Typed change channel for clipboard history mutations within this plugin.
@MainActor
final class ClipboardHistoryChangeCenter {
    static let shared = ClipboardHistoryChangeCenter()

    private var callbacks: [UUID: () -> Void] = [:]

    @discardableResult
    func addObserver(_ callback: @escaping () -> Void) -> ClipboardHistoryChangeToken {
        let id = UUID()
        callbacks[id] = callback
        return ClipboardHistoryChangeToken { [weak self] in
            self?.callbacks[id] = nil
        }
    }

    func notify() {
        callbacks.values.forEach { $0() }
    }
}

@MainActor
final class ClipboardHistoryChangeToken {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }

}

/// Observes clipboard-history broadcasts and asks the view model to refresh.
@MainActor
final class ClipboardHistoryObserver {
    private var token: ClipboardHistoryChangeToken?

    init(onChange: @escaping () -> Void) {
        token = ClipboardHistoryChangeCenter.shared.addObserver(onChange)
    }

    func cancel() {
        token?.cancel()
        token = nil
    }
}
