import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import SwiftUI
import KitSuperLog
import os

@MainActor
public final class DisplayControlSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.display-control", category: "DisplayControl")
    public let id = "com.coffic.lumi.plugin.display-control"
    public let order = 210
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.display-control",
        name: "Display Control",
        description: "Control brightness, volume, and contrast for external displays via DDC/CI.",
        category: .system,
        stage: .preview,
        policy: .disabledByDefault
    )

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { DisplayControlAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { DisplayControlManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let entryID = "\(id).entry"
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: metadata.name,
                    systemImage: "display",
                    order: order,
                    ownerPluginID: id
                ) {
                    if $0 == entryID {
                        content?.setContentView(AnyView(DisplayControlView()))
                    }
                },
            ])
        } else {
            content?.setContentView(AnyView(DisplayControlView()))
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: ["\(id).entry"])
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
