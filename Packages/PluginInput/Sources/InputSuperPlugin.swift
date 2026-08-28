import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderStorage
import SwiftUI
import KitSuperLog
import os

enum InputPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    static var fallbackRootDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
    }
}

@MainActor
public final class InputSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.input-manager", category: "Input")
    public let id = "com.coffic.lumi.plugin.input-manager"
    public let order = 70
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.input-manager",
        name: "Input Manager",
        description: "Configure input methods and their behavior.",
        category: .system,
        stage: .preview,
        policy: .disabledByDefault
    )

    private let activityItemID = "com.coffic.lumi.plugin.input-manager.entry"

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            InputPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
        }

        let content = kernel.resolveProvider((any ContentViewProviding).self)
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            activityBar.addItems([
                ActivityBarItem(
                    id: activityItemID,
                    title: metadata.name,
                    systemImage: "keyboard",
                    order: order,
                    ownerPluginID: id
                ) { [activityItemID] in
                    if $0 == activityItemID {
                        content?.setContentView(AnyView(InputSettingsView()))
                    }
                },
            ])
        } else {
            content?.setContentView(AnyView(InputSettingsView()))
        }

        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { InputAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { InputManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: [activityItemID])
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        InputPluginRuntimeBridge.dataRootDirectory = nil
    }
}
