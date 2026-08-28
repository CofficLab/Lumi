import KernelCore
import ProviderContentView
import ProviderDocsView
import ProviderWorkspace
import SwiftUI
import KitSuperLog
import os

/// KernelCore migration of the Netto firewall workspace.
///
/// The legacy plugin was deliberately disabled, so the V2 catalog keeps the
/// same disabled policy: it is present for compatibility and diagnostics but
/// does not publish a workspace until a future host explicitly enables it.
@MainActor
public final class NettoSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.netto", category: "Netto")
    public let id = "com.coffic.lumi.plugin.netto"
    public let order = 99
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.netto",
        name: "Netto Firewall Plugin",
        description: "Manage per-application macOS network permissions.",
        category: .system,
        stage: .preview,
        policy: .disabled
    )

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: "Netto Firewall") { NettoAboutView() })
            docs.addManual(DocsEntry(id: id, name: "Netto Firewall") { NettoManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let workspace = kernel.resolveProvider((any WorkspaceProviding).self)
        let content = kernel.resolveProvider((any ContentViewProviding).self)

        workspace?.registerContainer(
            WorkspaceContainer(
                id: id,
                title: LumiPluginLocalization.string("Netto Firewall", bundle: .module),
                systemImage: "shield.lefthalf.filled",
                order: order,
                railVisibility: .unsupported,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBodyVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ),
            ownerPluginID: id
        )
        content?.setContentView(AnyView(NettoDashboardView()))
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        kernel.resolveProvider((any WorkspaceProviding).self)?.unregisterContainers(ownerPluginID: id)
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
