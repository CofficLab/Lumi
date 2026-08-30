import KernelCore
import ProviderActivityBar
import ProviderToolbar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
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
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let rail = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let pluginID = id
        let railWidthStore = kernel
            .resolveProvider((any StorageProviding).self)
            .map { storage in
                FileRailViewWidthStore(
                    fileURL: storage
                        .pluginDataDirectory(for: pluginID)
                        .appendingPathComponent("rail-view-width.plist", isDirectory: false)
                )
            }
        rail?.addTabs([
            RailTabItem(
                id: railTabID,
                category: .general,
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
            ) { state in
                if state == .activated {
                    toolbar?.setVisibleCategories([.global, .general])
                    rail?.setVisibleCategories([.general])
                    rail?.setVisibleTabID(self.railTabID)
                    rail?.activateWidthProfile(
                        ownerID: pluginID,
                        recommended: RailViewWidth(minWidth: 240, idealWidth: 280, maxWidth: 400),
                        store: railWidthStore
                    )
                    content?.setContentView(AnyView(RClickSettingsView()))
                    chat?.setVisible(false)
                    rootView?.setContentHeaderViewHidden(true)
                } else {
                    toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                    chat?.setVisible(true)
                    rootView?.setContentHeaderViewHidden(false)
                    rail?.setVisibleCategories(Set(RailViewCategory.allCases))
                    rail?.deactivateWidthProfile(ownerID: pluginID)
                }
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == activityItemID
        activityBar?.removeItems(ids: [activityItemID])
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(ids: [railTabID])
        if wasActive {
            kernel.resolveProvider((any RailViewProviding).self)?.deactivateWidthProfile(ownerID: id)
            kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
            kernel.resolveProvider((any RootViewProviding).self)?.setContentHeaderViewHidden(false)
            kernel.resolveProvider((any RailViewProviding).self)?.setVisibleCategories(Set(RailViewCategory.allCases))
        }
        RClickPluginRuntimeBridge.dataRootDirectory = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
