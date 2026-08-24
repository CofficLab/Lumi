import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderStorage
import SwiftUI

@MainActor
public final class RClickSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.rclick"
    public let order = 50
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.rclick",
        name: "Right Click",
        description: "Configure right-click actions and preview their behavior.",
        category: .system,
        stage: .preview,
        policy: .disabledByDefault
    )

    private let activityItemID = "com.coffic.lumi.plugin.rclick.entry"
    private let railTabID = "com.coffic.lumi.plugin.rclick.preview"

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            RClickPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
        }

        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let rail = kernel.resolveProvider((any RailViewProviding).self)
        rail?.addTabs([
            RailTabItem(
                id: railTabID,
                groupID: id,
                title: "Preview",
                systemImage: "eye",
                order: order
            ) {
                RClickRailView()
            },
        ])

        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([
            ActivityBarItem(
                id: activityItemID,
                title: metadata.name,
                systemImage: "cursorarrow.click.2",
                order: order,
                ownerPluginID: id
            ) { [id, activityItemID] activeID in
                if activeID == activityItemID {
                    content?.setContentView(AnyView(RClickSettingsView()))
                    rail?.activateGroup(id: id)
                } else if rail?.activeGroupID == id {
                    rail?.activateGroup(id: nil)
                }
            },
        ])

        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { RClickAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { RClickManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: [activityItemID])
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(ids: [railTabID])
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        RClickPluginRuntimeBridge.dataRootDirectory = nil
    }
}
