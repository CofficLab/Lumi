import ProviderRailView

/// Persists Rail tab changes while Chat owns the Rail.
@MainActor
final class ChatPanelRailObserver {
    private var handle: (any RailViewProvidingObserverHandle)?
    private let activeTabStore: FileRailActiveTabStore

    var isActive = true

    init(rail: any RailViewProviding, activeTabStore: FileRailActiveTabStore) {
        self.activeTabStore = activeTabStore
        handle = rail.addObserver { [weak self] event in
            guard let self,
                  self.isActive,
                  case .activeTabChanged(let tabID) = event,
                  let tabID else { return }
            self.activeTabStore.save(tabID)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
