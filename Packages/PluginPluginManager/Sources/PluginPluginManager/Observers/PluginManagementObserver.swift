import KitSuperLog
import os
import ProviderPluginManaging

/// 观察插件管理能力，并将变化同步到插件管理页 ViewModel。
@MainActor
final class PluginManagementObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.plugin-manager",
        category: "PluginManagementObserver"
    )
    nonisolated static let verbose = false

    private let capability: any PluginManagementCapability
    private weak var viewModel: PluginManagementViewModel?
    private var handle: (any PluginManagingObserverHandle)?

    init(
        capability: any PluginManagementCapability,
        viewModel: PluginManagementViewModel
    ) {
        self.capability = capability
        self.viewModel = viewModel
        viewModel.refresh()
        handle = capability.addObserver { [weak self] event in
            self?.handle(event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
        viewModel = nil
    }

    private func handle(_ event: PluginManagingEvent) {
        if Self.verbose {
            Self.logger.info("plugin management event: \(String(describing: event), privacy: .public)")
        }
        viewModel?.refresh()
    }
}
