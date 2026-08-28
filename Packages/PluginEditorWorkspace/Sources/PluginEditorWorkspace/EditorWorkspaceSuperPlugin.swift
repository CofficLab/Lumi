import EditorContracts
import EditorService
import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderProject
import ProviderRailView
import SwiftUI

@MainActor
public final class EditorWorkspaceSuperPlugin: SuperPlugin {
    public static let pluginID = "com.coffic.lumi.plugin.editor-workspace"
    public static let activityItemID = "\(pluginID).entry"
    public static let explorerTabID = "\(pluginID).explorer"

    public let id = pluginID
    public let order = 82
    public let dependencies = ["com.coffic.lumi.plugin.editor-host"]
    public let metadata = PluginMetadata(
        id: pluginID,
        name: "Code Editor",
        description: "Browse projects and edit source files in a VS Code-style workspace.",
        version: "1.0.0",
        category: .editor,
        stage: .preview,
        policy: .disabledByDefault
    )

    private var controller: EditorWorkspaceController?
    private weak var activityBar: (any ActivityBarProviding)?
    private weak var railView: (any RailViewProviding)?
    private weak var contentView: (any ContentViewProviding)?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        try installContributions(kernel: kernel)
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        try installContributions(kernel: kernel)
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        uninstallContributions()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        uninstallContributions()
    }

    private func installContributions(kernel: KernelCoreContainer) throws {
        guard let editor = kernel.resolveProvider(EditorService.self) else {
            throw KernelCoreError.providerNotRegistered(type: EditorService.self)
        }
        guard let surface = kernel.resolveProvider(EditorSurfaceProviding.self) else {
            throw KernelCoreError.providerNotRegistered(type: EditorSurfaceProviding.self)
        }
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any ProjectProviding).self)
        }
        guard let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any ActivityBarProviding).self)
        }
        guard let railView = kernel.resolveProvider((any RailViewProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any RailViewProviding).self)
        }
        guard let contentView = kernel.resolveProvider((any ContentViewProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any ContentViewProviding).self)
        }

        uninstallContributions()
        let controller = EditorWorkspaceController(editor: editor, project: project)
        self.controller = controller
        self.activityBar = activityBar
        self.railView = railView
        self.contentView = contentView

        railView.addTabs([
            RailTabItem(
                id: Self.explorerTabID,
                groupID: id,
                title: "Explorer",
                systemImage: "doc.on.doc",
                order: order
            ) {
                EditorFileTreeView(controller: controller)
            },
        ])

        activityBar.addItems([
            ActivityBarItem(
                id: Self.activityItemID,
                title: "Code Editor",
                systemImage: "chevron.left.forwardslash.chevron.right",
                order: order,
                ownerPluginID: id
            ) { [weak railView, weak contentView] activeItemID in
                guard activeItemID == Self.activityItemID else { return }
                contentView?.setContentView(AnyView(EditorWorkbenchView(
                    controller: controller,
                    surface: surface
                )))
                railView?.activateGroup(id: Self.pluginID)
            },
        ])
    }

    private func uninstallContributions() {
        let ownedCurrentContent = activityBar?.activeItemID == Self.activityItemID
        railView?.removeTabs(ids: [Self.explorerTabID])
        activityBar?.removeItems(ids: [Self.activityItemID])
        if ownedCurrentContent { contentView?.setContentView(nil) }
        controller = nil
        activityBar = nil
        railView = nil
        contentView = nil
    }
}
