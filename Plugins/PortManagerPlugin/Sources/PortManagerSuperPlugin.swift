import KernelCore
import LumiUI
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderToolbar
import SwiftUI

@MainActor
public final class PortManagerSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.port-manager"
    public let order = 43
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.port-manager",
        name: "Port Manager",
        description: "Inspect local listening ports.",
        category: .system,
        stage: .preview,
        policy: .disabled
    )

    private let activityItemID = "com.coffic.lumi.plugin.port-manager.entry"
    private let titleItemID = "com.coffic.lumi.plugin.port-manager.title"

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let title = metadata.name
        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([
            ActivityBarItem(
                id: activityItemID,
                title: title,
                systemImage: "arrow.up.arrow.down.circle",
                order: order,
                ownerPluginID: id
            ) { [activityItemID, titleItemID] activeID in
                if activeID == activityItemID {
                    content?.setContentView(AnyView(PortManagerView()))
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
        kernel.resolveProvider((any DocsViewProviding).self)?.addManual(
            DocsEntry(id: id, name: title) { PortManagerManualView() }
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: [activityItemID])
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: [titleItemID])
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
