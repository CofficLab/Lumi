import Combine
import Foundation

/// Observes clipboard-history broadcasts and asks the view model to refresh.
@MainActor
final class ClipboardHistoryObserver {
    private var cancellable: AnyCancellable?

    init(onChange: @escaping () -> Void) {
        cancellable = NotificationCenter.default.publisher(for: .clipboardHistoryDidUpdate)
            .receive(on: RunLoop.main)
            .sink { _ in onChange() }
    }

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}
