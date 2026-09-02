import Foundation
import ProviderPluginManaging

/// Forwards plugin-manager changes to ActivityBar visibility reconciliation.
@MainActor
final class PluginManagerObserver {
    private var handle: (any PluginManagingObserverHandle)?

    init(pluginManager: any PluginManaging, onChange: @escaping () -> Void) {
        handle = pluginManager.addPluginObserver { _ in
            onChange()
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
