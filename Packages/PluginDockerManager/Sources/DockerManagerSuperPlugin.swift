import KernelCore
import LumiUI
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderToolbar
import SwiftUI
import os

struct DockerManagerPlugin {
    let name = "Docker"
    init() {}
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "DockerManagerPlugin")
}

@MainActor
public final class DockerManagerSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.docker-manager"
    public let order = 50
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.docker-manager",
        name: "Docker",
        description: "Inspect and manage Docker images and containers.",
        category: .system,
        stage: .preview,
        policy: .disabled
    )

    private let activityItemID = "com.coffic.lumi.plugin.docker-manager.entry"
    private let titleItemID = "com.coffic.lumi.plugin.docker-manager.title"

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let title = metadata.name
        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([
            ActivityBarItem(
                id: activityItemID,
                title: title,
                systemImage: "shippingbox",
                order: order,
                ownerPluginID: id
            ) { [activityItemID, titleItemID] activeID in
                if activeID == activityItemID {
                    content?.setContentView(AnyView(DockerImagesView()))
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
            DocsEntry(id: id, name: title) { DockerManagerManualView() }
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: [activityItemID])
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: [titleItemID])
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
