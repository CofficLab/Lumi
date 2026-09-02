import Combine
import Foundation

/// Observes idle-time snapshot broadcasts and asks the view model to refresh.
@MainActor
final class IdleTimeSnapshotObserver {
    private var cancellable: AnyCancellable?

    init(onChange: @escaping () -> Void) {
        cancellable = NotificationCenter.default.publisher(for: .idleTimeSnapshotDidChange)
            .receive(on: RunLoop.main)
            .sink { _ in onChange() }
    }

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}
