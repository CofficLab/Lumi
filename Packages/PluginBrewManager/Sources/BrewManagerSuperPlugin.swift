import KernelCore
import LumiUI
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderToolbar
import SwiftUI
import os

struct BrewManagerPlugin {
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "BrewManagerPlugin")
}

extension Notification.Name {
    static let brewManagerRefreshRequested = Notification.Name("BrewManagerRefreshRequested")
}

@MainActor
public final class BrewManagerSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.brew-manager"
    public let order = 260
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.brew-manager",
        name: "Package Management",
        description: "Manage Homebrew packages and casks.",
        category: .system,
        stage: .preview,
        policy: .disabledByDefault
    )

    private let activityItemID = "com.coffic.lumi.plugin.brew-manager.entry"
    private let refreshItemID = "com.coffic.lumi.plugin.brew-manager.refresh"

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([
            ActivityBarItem(
                id: activityItemID,
                title: metadata.name,
                systemImage: "mug.fill",
                order: order,
                ownerPluginID: id
            ) { [activityItemID, refreshItemID] activeID in
                if activeID == activityItemID {
                    content?.setContentView(AnyView(BrewManagerView()))
                    toolbar?.addToolbarItems([
                        ToolbarItem(id: refreshItemID, title: "Refresh", placement: .trailing, order: 260) {
                            AppIconButton(systemImage: "arrow.clockwise") {
                                NotificationCenter.default.post(name: .brewManagerRefreshRequested, object: nil)
                            }
                            .help("Refresh")
                        },
                    ])
                } else {
                    toolbar?.removeToolbarItems(ids: [refreshItemID])
                }
            },
        ])

        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { AboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { BrewManagerManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: [activityItemID])
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: [refreshItemID])
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
