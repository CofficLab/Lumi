import Combine
import ProviderIdleTime

@MainActor
public final class ActivityHeatmapIdleTimeState: ObservableObject {
    @Published private(set) var snapshot: IdleInferenceSnapshot?
    private let provider: (any IdleTimeProviding)?

    public init(provider: (any IdleTimeProviding)?) {
        self.provider = provider
    }

    public func refresh() {
        guard let provider else { return }
        Task { [weak self] in
            let snapshot = await provider.currentSnapshot()
            self?.snapshot = snapshot
        }
    }
}

/// Adapts the provider's typed change channel to the Activity Heatmap state.
/// The plugin entry point owns this observer.
@MainActor
final class ActivityHeatmapIdleTimeObserver {
    private var handle: IdleTimeProvidingObserverHandle?

    init(provider: any IdleTimeProviding, onChange: @escaping @Sendable () -> Void) {
        handle = provider.addObserver { _ in
            Task { @MainActor in onChange() }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
