import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderStorage
import SwiftUI

@MainActor public final class ImageToPDFSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.image-to-pdf"; public let order = 875
    public let metadata = PluginMetadata(id: "com.coffic.lumi.plugin.image-to-pdf", name: "Image to PDF", description: "Drop image files and convert each one to a single-page PDF.", category: .project, stage: .preview, policy: .disabledByDefault)
    public init() {}
    public func onBoot(kernel: KernelCoreContainer) throws {
        ImageToPDFRuntimeBridge.directoryURL = kernel.resolveProvider((any StorageProviding).self)?.pluginDataDirectory(for: "ImageToPDF")
        let content = kernel.resolveProvider((any ContentViewProviding).self); let entry = "\(id).entry"
        if let bar = kernel.resolveProvider((any ActivityBarProviding).self) { bar.addItems([ActivityBarItem(id: entry, title: metadata.name, systemImage: "photo.on.rectangle.angled", order: order, ownerPluginID: id) { if $0 == entry { content?.setContentView(AnyView(ImageToPDFMainView())) } }]) } else { content?.setContentView(AnyView(ImageToPDFMainView())) }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) { docs.addAbout(DocsEntry(id: id, name: metadata.name) { ImageToPDFAboutView() }); docs.addManual(DocsEntry(id: id, name: metadata.name) { ImageToPDFManualView() }) }
    }
    public func onShutdown(kernel: KernelCoreContainer) throws { kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: ["\(id).entry"]); kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id); ImageToPDFRuntimeBridge.directoryURL = nil }
}
