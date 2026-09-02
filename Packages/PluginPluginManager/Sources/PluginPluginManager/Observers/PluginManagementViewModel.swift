import Combine
import ProviderPluginManaging
import SwiftUI

/// Observes plugin-manager changes for the plugin management settings page.
@MainActor
final class PluginManagementViewModel: ObservableObject {
    let manager: any PluginManaging
    @Published private(set) var revision = 0
    private var observer: (any PluginManagingObserverHandle)?

    init(manager: any PluginManaging) {
        self.manager = manager
        observer = manager.addPluginObserver { [weak self] _ in
            self?.revision &+= 1
        }
    }

}
