import ProviderRailView

/// Persists Rail tab changes while Chat owns the Rail.
@MainActor
final class ChatPanelRailObserver {
    private var handle: (any RailViewProvidingObserverHandle)?
    private let activeTabStore: FileRailActiveTabStore
    private let onRailStructureChanged: () -> Void

    var isActive = true

    init(
        rail: any RailViewProviding,
        activeTabStore: FileRailActiveTabStore,
        onRailStructureChanged: @escaping () -> Void
    ) {
        self.activeTabStore = activeTabStore
        self.onRailStructureChanged = onRailStructureChanged
        handle = rail.addObserver { [weak self] event in
            guard let self, self.isActive else { return }
            switch event {
            case .tabsChanged, .didAppear:
                self.onRailStructureChanged()
            case .activeTabChanged(let tabID):
                guard let tabID else { return }
                self.activeTabStore.save(tabID)
            default:
                break
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
