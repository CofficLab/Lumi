import KernelCore
import KitSuperLog
import os
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
import ProviderStorage
import SwiftUI

@MainActor public final class ImageToPDFSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.image-to-pdf", category: "ImageToPDF")
    public let id = "com.coffic.lumi.plugin.image-to-pdf"; public let order = 875
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.image-to-pdf",
        name: "Image to PDF",
        description: "Drop image files and convert each one to a single-page PDF.",
        category: .project,
        stage: .preview,
        policy: .disabledByDefault
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        ImageToPDFRuntimeBridge.directoryURL = kernel.resolveProvider((any StorageProviding).self)?.pluginDataDirectory(for: "ImageToPDF")
        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let root = kernel.resolveProvider((any RootViewProviding).self)
        let rail = kernel.resolveProvider((any RailViewProviding).self)
        let entry = "\(id).entry"

        if let bar = kernel.resolveProvider((any ActivityBarProviding).self) {
            bar.addItems([
                ActivityBarItem(id: entry, title: metadata.name, systemImage: "photo.on.rectangle.angled", order: order, ownerPluginID: id) { activeItemID in
                    if activeItemID == entry {
                        root?.setRailView(nil)
                        content?.setContentView(AnyView(ImageToPDFMainView()))
                    } else {
                        root?.setRailView(rail?.makeRailView())
                    }
                },
            ])
        } else {
            content?.setContentView(AnyView(ImageToPDFMainView()))
        }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) { docs.addAbout(DocsEntry(id: id, name: metadata.name) { ImageToPDFAboutView() }); docs.addManual(DocsEntry(id: id, name: metadata.name) { ImageToPDFManualView() }) }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws { kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: ["\(id).entry"]); kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id); ImageToPDFRuntimeBridge.directoryURL = nil }
}
