import Foundation
import KitSuperLog
import os
import ProviderActivityBar
import ProviderPluginManaging
import ProviderRootView

/// Owns plugin-manager subscriptions and ActivityBar visibility reconciliation.
@MainActor
final class PluginManagerObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.activity-bar",
        category: "PluginManagerObserver"
    )
    nonisolated static let verbose = true

    private let pluginManager: any PluginManaging
    private let provider: ActivityBarProvider
    private weak var rootView: (any RootViewProviding)?
    private weak var viewModel: ActivityBarViewModel?
    private var observationHandle: (any PluginManagingObserverHandle)?
    private var activityBarObservationHandle: (any ActivityBarObserverHandle)?
    private var lastKnownEnabledPluginIDs: Set<String>
    private var pendingActiveItemID: String?

    init(
        pluginManager: any PluginManaging,
        provider: ActivityBarProvider,
        rootView: (any RootViewProviding)?,
        pendingActiveItemID: String?,
        viewModel: ActivityBarViewModel
    ) {
        self.pluginManager = pluginManager
        self.provider = provider
        self.rootView = rootView
        self.viewModel = viewModel
        self.pendingActiveItemID = pendingActiveItemID
        self.lastKnownEnabledPluginIDs = Self.currentEnabledPluginIDs(pluginManager: pluginManager)
        viewModel.refresh()
        if Self.verbose {
            Self.logger.info("\(Self.t)initialized: enabledPlugins=\(self.lastKnownEnabledPluginIDs.count, privacy: .public), items=\(provider.items.count, privacy: .public), pendingActive=\(pendingActiveItemID ?? "nil", privacy: .public)")
        }
        observationHandle = pluginManager.addPluginObserver { [weak self] event in
            self?.handle(event)
        }
        activityBarObservationHandle = provider.addActivityBarObserver { [weak self] event in
            self?.handle(activityBarEvent: event)
        }
    }

    func cancel() {
        if Self.verbose {
            Self.logger.info("\(Self.t)cancel: items=\(self.provider.items.count, privacy: .public), enabledPlugins=\(self.lastKnownEnabledPluginIDs.count, privacy: .public)")
        }
        observationHandle?.cancel()
        observationHandle = nil
        activityBarObservationHandle?.cancel()
        activityBarObservationHandle = nil
        viewModel = nil
    }

    private func handle(activityBarEvent event: ActivityBarEvent) {
        if Self.verbose {
            Self.logger.info("\(Self.t)received ActivityBar event: \(String(describing: event), privacy: .public)")
        }
        viewModel?.refresh()
    }

    private func handle(_ event: PluginManagingEvent) {
        if Self.verbose {
            Self.logger.info("\(Self.t)received event: \(String(describing: event), privacy: .public)")
        }

        let currentIDs = Self.currentEnabledPluginIDs(pluginManager: pluginManager)
        let removed = lastKnownEnabledPluginIDs.subtracting(currentIDs)
        let added = currentIDs.subtracting(lastKnownEnabledPluginIDs)
        if Self.verbose {
            Self.logger.info("\(Self.t)visibility diff: previous=\(self.lastKnownEnabledPluginIDs.count, privacy: .public), current=\(currentIDs.count, privacy: .public), removed=\(removed.count, privacy: .public), added=\(added.count, privacy: .public), itemsBefore=\(self.provider.items.count, privacy: .public)")
        }

        for pluginID in removed {
            provider.hideItems(forPluginID: pluginID)
        }
        for pluginID in added {
            provider.restoreItems(forPluginID: pluginID)
        }

        restorePendingActiveItemIfAvailable()
        lastKnownEnabledPluginIDs = currentIDs
        syncContentFooterVisibility()
        viewModel?.refresh()

        if Self.verbose {
            Self.logger.info("\(Self.t)visibility sync complete: itemsAfter=\(self.provider.items.count, privacy: .public), shouldDisplay=\(self.provider.shouldDisplayActivityBar, privacy: .public), active=\(self.provider.activeItemID ?? "nil", privacy: .public)")
        }
    }

    private func restorePendingActiveItemIfAvailable() {
        guard let pendingActiveItemID,
              provider.items.contains(where: { $0.id == pendingActiveItemID }) else {
            return
        }

        provider.activateItem(id: pendingActiveItemID)
        self.pendingActiveItemID = nil
        if Self.verbose {
            Self.logger.info("\(Self.t)restored pending active item: \(pendingActiveItemID, privacy: .public)")
        }
    }

    private func syncContentFooterVisibility() {
        let shouldPreserve = provider.items
            .first(where: { $0.id == provider.activeItemID })?
            .preservesContentFooter ?? false
        rootView?.setContentFooterViewHidden(!shouldPreserve)
    }

    private static func currentEnabledPluginIDs(pluginManager: any PluginManaging) -> Set<String> {
        Set(pluginManager.allPlugins
            .filter { pluginManager.isEnabled(id: $0.id) }
            .map(\.id))
    }
}
