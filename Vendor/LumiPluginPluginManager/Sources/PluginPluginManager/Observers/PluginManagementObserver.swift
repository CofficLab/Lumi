import LumiLoggingKit
import os
import ProviderPluginManaging

/// 观察插件管理能力，并将变化同步到插件管理页 ViewModel。
@MainActor
final class PluginManagementObserver: SuperLog {
    /// 日志子系统跟随宿主注入的插件 id，便于在系统日志中区分品牌。
    nonisolated let logger: Logger
    nonisolated static let verbose = false

    private let capability: any PluginManagementCapability
    private weak var viewModel: PluginManagementViewModel?
    private var handle: (any PluginManagingObserverHandle)?

    init(
        capability: any PluginManagementCapability,
        viewModel: PluginManagementViewModel,
        subsystem: String
    ) {
        self.capability = capability
        self.viewModel = viewModel
        self.logger = Logger(subsystem: subsystem, category: "PluginManagementObserver")
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
            logger.info("plugin management event: \(String(describing: event), privacy: .public)")
        }
        viewModel?.refresh()
    }
}
