import EditorContracts
import EditorService
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderConversationInput
import ProviderDocsView
import ProviderProject
import ProviderRailView
import ProviderRootView
import ProviderToolbar
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
        name: CodeEditorLocalization.string("Code Editor"),
        description: CodeEditorLocalization.string("Browse projects and edit source files in a VS Code-style workspace."),
        version: "1.0.0",
        category: .editor,
        stage: .preview,
        policy: .disabledByDefault
    )

    private var viewModel: CodeEditorViewModel?
    private var editor: EditorService?
    private var sendSelectionContributor: SendSelectionToConversationContributor?
    private var projectObserver: (any ProjectProvidingObserverHandle)?
    private weak var activityBar: (any ActivityBarProviding)?
    private weak var contentView: (any ContentViewProviding)?
    private weak var chat: (any ChatSectionProviding)?
    private weak var railView: (any RailViewProviding)?
    private weak var rootView: (any RootViewProviding)?

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
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let chatContext = ChatContext(
            id: id,
            title: metadata.name,
            subtitle: metadata.description.isEmpty ? nil : metadata.description,
            systemImage: "chevron.left.forwardslash.chevron.right"
        )
        uninstallContributions()
        let sendSelectionContributor = SendSelectionToConversationContributor(
            conversationInput: kernel.resolveProvider((any ConversationInputProviding).self)
        )
        editor.editorExtensions.registerContextMenuContributor(sendSelectionContributor)
        let viewModel = CodeEditorViewModel(editor: editor)
        viewModel.updateCurrentFile(project.currentFileURL)
        let projectObserver = project.addObserver { [weak viewModel] event in
            guard case .currentFileChanged(let fileURL) = event else { return }
            viewModel?.updateCurrentFile(fileURL)
        }

        self.viewModel = viewModel
        self.editor = editor
        self.sendSelectionContributor = sendSelectionContributor
        self.projectObserver = projectObserver
        self.activityBar = activityBar
        self.contentView = contentView
        self.chat = chat
        self.railView = kernel.resolveProvider((any RailViewProviding).self)
        self.rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        activityBar.addItems([
            ActivityBarItem(
                id: Self.activityItemID,
                title: CodeEditorLocalization.string("Code Editor"),
                systemImage: "chevron.left.forwardslash.chevron.right",
                order: order,
                ownerPluginID: id
            ) { [weak contentView, weak railView = self.railView, weak rootView = self.rootView, weak chat] state in
                if state == .activated {
                    toolbar?.setVisibleCategories([.global, .chat, .project, .editor])
                    // Code Editor 是唯一需要显示 ContentHeader 的工作区。
                    rootView?.setContentHeaderViewHidden(false)
                    // Code Editor 激活时只显示文件树，避免带出其它项目类 RailView。
                    railView?.setVisibleCategories([.fileTree])
                    chat?.setVisible(true)
                    chat?.setContextActive(true)
                    chat?.setActiveContext(chatContext)
                    contentView?.setContentView(AnyView(EditorWorkbenchView(
                        viewModel: viewModel,
                        surface: surface
                    )))
                } else {
                    toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                    rootView?.setContentHeaderViewHidden(true)
                    chat?.setActiveContext(nil)
                }
            },
        ])
    }

    private func uninstallContributions() {
        editor?.editorExtensions.unregisterContextMenuContributor(
            id: SendSelectionToConversationContributor.contributorID
        )
        let ownedCurrentContent = activityBar?.activeItemID == Self.activityItemID
        if ownedCurrentContent {
            chat?.setActiveContext(nil)
        }
        activityBar?.removeItems(ids: [Self.activityItemID])
        if ownedCurrentContent { contentView?.setContentView(nil) }
        if ownedCurrentContent {
            rootView?.setContentHeaderViewHidden(true)
            railView?.setVisibleCategories(Set(RailViewCategory.allCases))
        }
        projectObserver?.cancel()
        projectObserver = nil
        viewModel = nil
        sendSelectionContributor = nil
        editor = nil
        activityBar = nil
        contentView = nil
        chat = nil
        railView = nil
        rootView = nil
    }
}
