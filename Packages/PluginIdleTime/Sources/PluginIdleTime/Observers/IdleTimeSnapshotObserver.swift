import Foundation
import ProviderIdleTime

/// Observes idle-time snapshot broadcasts and asks the view model to refresh.
@MainActor
final class IdleTimeSnapshotObserver {
    private var handle: IdleTimeProvidingObserverHandle?
    private var timer: Timer?

    init(provider: any IdleTimeProviding, onChange: @escaping @Sendable () -> Void) {
        handle = provider.addObserver { _ in
            Task { @MainActor in onChange() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { _ in
            Task { @MainActor in onChange() }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
        timer?.invalidate()
        timer = nil
    }
}
