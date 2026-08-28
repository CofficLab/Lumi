import KernelCore
import LumiUI
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderToolbar
import SwiftUI
import KitSuperLog
import os

@MainActor
public final class RegistryManagerSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.registry-manager", category: "RegistryManager")
    public let id = "com.coffic.lumi.plugin.registry-manager"
    public let order = 80
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.registry-manager",
        name: "Registry Manager",
        description: "Manage Lumi registries.",
        category: .system,
        stage: .preview,
        policy: .disabled
    )

    private let activityItemID = "com.coffic.lumi.plugin.registry-manager.entry"
    private let titleItemID = "com.coffic.lumi.plugin.registry-manager.title"

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let title = metadata.name
        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([
            ActivityBarItem(
                id: activityItemID,
                title: title,
                systemImage: "arrow.triangle.2.circlepath",
                order: order,
                ownerPluginID: id
            ) { [activityItemID, titleItemID] activeID in
                if activeID == activityItemID {
                    content?.setContentView(AnyView(RegistryManagerView()))
                    toolbar?.addToolbarItems([
                        ToolbarItem(id: titleItemID, title: title, placement: .center, order: 0) {
                            AppToolbarTitleLabel(title: title)
                        },
                    ])
                } else {
                    toolbar?.removeToolbarItems(ids: [titleItemID])
                }
            },
        ])
        kernel.resolveProvider((any DocsViewProviding).self)?.addAbout(
            DocsEntry(id: id, name: title) { RegistryManagerAboutView() }
        )
        kernel.resolveProvider((any DocsViewProviding).self)?.addManual(
            DocsEntry(id: id, name: title) { RegistryManagerManualView() }
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: [activityItemID])
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: [titleItemID])
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
