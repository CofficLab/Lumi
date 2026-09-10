import KernelCore
import KitSuperLog
import LumiUI
import os
import ProviderDeveloperMode
import ProviderToolbar
import SwiftUI

/// Provides the runtime developer-mode switch and its toolbar control.
@MainActor
public final class DeveloperModePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.developer-mode",
        category: "DeveloperMode"
    )

    public let id = "com.coffic.lumi.plugin.developer-mode"
    public let order = 1

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.developer-mode",
        name: "Developer Mode",
        description: "Runtime controls for development-only diagnostics",
        category: .general,
        stage: .stable,
        policy: .alwaysOn
    )

    private var provider: (any DeveloperModeProviding)?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let provider = kernel.resolveProvider((any DeveloperModeProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve DeveloperModeProviding from kernel")
            return
        }
        self.provider = provider

        guard let toolbar = kernel.resolveProvider((any ToolbarProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolbarProviding from kernel")
            return
        }

        var toolbarItems = [ProviderToolbar.ToolbarItem]()
#if DEBUG
        toolbarItems.append(
            ProviderToolbar.ToolbarItem(
                id: "\(id).toggle",
                title: LumiPluginLocalization.string("Developer mode"),
                placement: .leading,
                category: .global,
                order: 5
            ) {
                DeveloperModeToggleView(provider: provider)
            }
        )
#endif
#if DEBUG
        toolbarItems.append(
            ProviderToolbar.ToolbarItem(
                id: "\(id).badge",
                title: LumiPluginLocalization.string("Running a Debug build"),
                placement: .leading,
                category: .global,
                order: 900
            ) {
                DebugBadgeView()
            }
        )
#endif
        toolbar.addToolbarItems(toolbarItems)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        var toolbarItemIDs = ["\(id).toggle"]
#if DEBUG
        toolbarItemIDs.append("\(id).badge")
#endif
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(
            ids: Set(toolbarItemIDs)
        )
        provider = nil
    }
}
