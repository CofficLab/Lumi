import EditorContracts
import EditorService
import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderProject
import ProviderRailView
import ProviderRootView
import SwiftUI
import KitSuperLog
import os

@MainActor
public final class CodeEditorSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.code-editor", category: "CodeEditor")
    public static let pluginID = "com.coffic.lumi.plugin.code-editor"
    public static let activityItemID = "\(pluginID).entry"

    public let id = pluginID
    public let order = 82
    public let dependencies = [
        "com.coffic.lumi.plugin.editor-host",
    ]
    public let metadata = PluginMetadata(
        id: pluginID,
        name: "Code Editor",
        description: "Browse projects and edit source files in a VS Code-style workspace.",
        version: "1.0.0",
        category: .editor,
        stage: .preview,
        policy: .disabledByDefault
    )

    private var viewModel: CodeEditorViewModel?
    private var projectObserver: (any ProjectProvidingObserverHandle)?
    private weak var activityBar: (any ActivityBarProviding)?
    private weak var contentView: (any ContentViewProviding)?
    private weak var rootView: (any RootViewProviding)?
    private weak var railView: (any RailViewProviding)?

    public init() {}

    /// 文档属于插件目录型贡献，必须在插件注册阶段加入系统，
    /// 即使插件当前处于 disabledByDefault 也能在设置中查看。
    public func onRegister(kernel: KernelCoreContainer) throws {
        guard let docs = kernel.resolveProvider((any DocsViewProviding).self) else { return }
        docs.addAbout(DocsEntry(id: id, name: metadata.name) { CodeEditorAboutView() })
        docs.addManual(DocsEntry(id: id, name: metadata.name) { CodeEditorManualView() })
    }

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

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
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
        guard let contentView = kernel.resolveProvider((any ContentViewProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any ContentViewProviding).self)
        }
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)

        uninstallContributions()
        let viewModel = CodeEditorViewModel(editor: editor)
        viewModel.updateCurrentFile(project.currentFileURL)
        let projectObserver = project.addObserver { [weak viewModel] event in
            guard case .currentFileChanged(let fileURL) = event else { return }
            viewModel?.updateCurrentFile(fileURL)
        }

        self.viewModel = viewModel
        self.projectObserver = projectObserver
        self.activityBar = activityBar
        self.contentView = contentView
        self.rootView = rootView
        self.railView = railView

        activityBar.addItems([
            ActivityBarItem(
                id: Self.activityItemID,
                title: "Code Editor",
                systemImage: "chevron.left.forwardslash.chevron.right",
                order: order,
                ownerPluginID: id
            ) { [weak contentView, weak rootView, weak railView] activeItemID in
                guard activeItemID == Self.activityItemID else { return }
                rootView?.setRailView(railView?.makeRailView())
                contentView?.setContentView(AnyView(EditorWorkbenchView(
                    viewModel: viewModel,
                    surface: surface
                )))
            },
        ])
    }

    private func uninstallContributions() {
        let ownedCurrentContent = activityBar?.activeItemID == Self.activityItemID
        activityBar?.removeItems(ids: [Self.activityItemID])
        if ownedCurrentContent { contentView?.setContentView(nil) }
        projectObserver?.cancel()
        projectObserver = nil
        viewModel = nil
        activityBar = nil
        contentView = nil
        rootView = nil
        railView = nil
    }
}
