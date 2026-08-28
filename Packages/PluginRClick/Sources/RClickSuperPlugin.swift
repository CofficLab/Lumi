import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderStorage
import SwiftUI
import KitSuperLog
import os

@MainActor
public final class RClickSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.rclick", category: "RClick")
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

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { RClickAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { RClickManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            RClickPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
        }

        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let rail = kernel.resolveProvider((any RailViewProviding).self)
        rail?.addTabs([
            RailTabItem(
                id: railTabID,
                title: LumiPluginLocalization.string("Preview", bundle: .module),
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
            ) { [activityItemID] activeID in
                if activeID == activityItemID {
                    content?.setContentView(AnyView(RClickSettingsView()))
                }
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: [activityItemID])
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(ids: [railTabID])
        RClickPluginRuntimeBridge.dataRootDirectory = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
