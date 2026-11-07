import Foundation
import LumiLoggingKit
import os
import ProviderPluginManaging
import ProviderToolbar

@MainActor
final class PluginToolbarStateObserver: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.shared.plugin.toolbar", category: "StateObserver")
    nonisolated static let verbose = false

    private let pluginManager: any PluginManaging
    private let providers: [any ToolbarPluginStateProviding]
    private var observationHandle: (any PluginManagingObserverHandle)?

    init(
        pluginManager: any PluginManaging,
        providers: [any ToolbarPluginStateProviding]
    ) {
        self.pluginManager = pluginManager
        self.providers = providers
        sync()
        observationHandle = pluginManager.addPluginObserver { [weak self] event in
            switch event {
            case .listChanged, .enabledStateChanged:
                self?.sync()
            }
        }
    }

    func cancel() {
        observationHandle?.cancel()
        observationHandle = nil
    }

    private func sync() {
        let plugins = pluginManager.allPlugins
        let knownPluginIDs = Set(plugins.map(\.id))
        let disabledPluginIDs = Set(plugins
            .filter { !pluginManager.isEnabled(id: $0.id) }
            .map(\.id))

        for provider in providers {
            provider.setPluginState(
                knownPluginIDs: knownPluginIDs,
                disabledPluginIDs: disabledPluginIDs
            )
        }
    }
}
