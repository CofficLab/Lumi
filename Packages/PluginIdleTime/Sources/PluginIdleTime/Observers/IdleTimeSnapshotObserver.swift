import Foundation
import ProviderIdleTime

/// Observes idle-time snapshot broadcasts and asks the view model to refresh.
@MainActor
final class IdleTimeSnapshotObserver {
    private var handle: IdleTimeSnapshotChangeHandle?

    init(onChange: @escaping @Sendable () -> Void) {
        handle = IdleTimeSnapshotChangeCenter.shared.addObserver {
            Task { @MainActor in onChange() }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
