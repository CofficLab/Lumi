import KernelCore
import KitSuperLog
import os
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderStorage
import SwiftUI

@MainActor public final class AppManagerSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.app-manager", category: "AppManager")
    public let id = "com.coffic.lumi.plugin.app-manager"; public let order = 242
    public let metadata = PluginMetadata(id: "com.coffic.lumi.plugin.app-manager", name: "App Manager", description: "Browse installed macOS applications.", category: .system, stage: .preview, policy: .disabledByDefault)
    private let viewModel = AppManagerViewModel(); public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { AppManagerAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { AppManagerManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        if let storage = kernel.resolveProvider((any StorageProviding).self) { AppManagerPlugin.pluginDataDirectoryProvider = { storage.pluginDataDirectory(for: "AppManagerPlugin") } }
        let content = kernel.resolveProvider((any ContentViewProviding).self); let rail = kernel.resolveProvider((any RailViewProviding).self); let entry = "\(id).entry"
        rail?.addTabs([RailTabItem(id: AppManagerPlugin.railTabID, category: .system, title: LumiPluginLocalization.string("Apps", bundle: .module), systemImage: "apps.ipad", order: order) { AppRailView(viewModel: self.viewModel) }])
        if let bar = kernel.resolveProvider((any ActivityBarProviding).self) { bar.addItems([ActivityBarItem(id: entry, title: metadata.name, systemImage: "apps.ipad", order: order, ownerPluginID: id) { if $0 == entry { content?.setContentView(AnyView(AppManagerView(viewModel: self.viewModel))) } }]) } else { content?.setContentView(AnyView(AppManagerView(viewModel: viewModel))) }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: ["\(id).entry"])
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(ids: [AppManagerPlugin.railTabID])
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
