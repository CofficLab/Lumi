import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import SwiftUI
import os

enum ClipboardManagerPlugin {
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "ClipboardManagerPlugin")
}

@MainActor
public final class ClipboardManagerSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.clipboard-manager"
    public let order = 270
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.clipboard-manager",
        name: "Clipboard",
        description: "Clipboard history manager.",
        category: .system,
        stage: .preview,
        policy: .disabledByDefault
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        ClipboardMonitor.shared.startMonitoring()
        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let entry = "\(id).entry"

        if let bar = kernel.resolveProvider((any ActivityBarProviding).self) {
            bar.addItems([
                ActivityBarItem(
                    id: entry,
                    title: metadata.name,
                    systemImage: "doc.on.clipboard",
                    order: order,
                    ownerPluginID: id
                ) {
                    if $0 == entry {
                        content?.setContentView(AnyView(ClipboardHistoryView()))
                    }
                },
            ])
        } else {
            content?.setContentView(AnyView(ClipboardHistoryView()))
        }

        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) {
                ClipboardManagerAboutView()
            })
            docs.addManual(DocsEntry(id: id, name: metadata.name) {
                ClipboardManagerManualView()
            })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        ClipboardMonitor.shared.stopMonitoring()
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: ["\(id).entry"])
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
