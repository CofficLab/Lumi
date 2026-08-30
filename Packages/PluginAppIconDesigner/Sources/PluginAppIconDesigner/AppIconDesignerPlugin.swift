import KernelCore
import KitAgentTool
import KitSuperLog
import os
import ProviderActivityBar
import ProviderToolbar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderPromptSuggestion
import ProviderRailView
import ProviderStorage
import ProviderRootView
import ProviderToolManager
import SwiftUI

/// App Icon 设计器插件。
@MainActor
public final class AppIconDesignerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.app-icon-designer", category: "AppIconDesigner")
    public let id = "com.coffic.lumi.plugin.app-icon-designer"
    public let order = 79
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.app-icon-designer",
        name: "App Icon Designer",
        description: "",
        category: .design,
        stage: .stable,
        policy: .disabledByDefault
    )

    public static let railTabID = "app-icon-designer.documents"

    public var name: String {
        AppIconDesignerLocalization.string("AppIconDesigner Name")
    }

    public init() {}

    private var promptSuggestion: PromptSuggestion {
        PromptSuggestion(
            id: "\(id).design",
            title: AppIconDesignerLocalization.string("Prompt.Suggestion.Design"),
            order: order * 1_000,
            systemImage: "app.dashed",
            action: .activatePluginEntry(
                activityBarItemID: "\(id).entry",
                railTabID: Self.railTabID
            ),
            scope: .launcherAndContext(id)
        )
    }

    private func registerPromptSuggestion(kernel: KernelCoreContainer, requiresEnable: Bool) {
        var suggestion = promptSuggestion
        suggestion.pluginID = id
        suggestion.requiresEnable = requiresEnable
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.register(suggestion)
    }

    public func onRegister(kernel: KernelCoreContainer) throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: !kernel.isPluginEnabled(id: id))

        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { DesignerAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { DesignerManualView() })
        } else {
            Self.logger.error("\(Self.t) DocsViewProviding not found")
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        IconDesignerRuntime.configure(kernel: kernel, pluginID: id)

        // 注册 Agent 工具到 ToolManagerProviding
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        } else {
            Self.logger.error("\(Self.t) ToolManagerProviding not found")
        }

        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let chatContext = ChatContext(
            id: id,
            title: name,
            subtitle: metadata.description.isEmpty ? nil : metadata.description,
            systemImage: "app.dashed"
        )
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)

        // 必须先注册 Rail，再注册 ActivityBar，确保首次激活回调能找到贡献。
        if let railView = railView {
            railView.addTabs([
                RailTabItem(
                    id: Self.railTabID,
                    category: .design,
                    title: AppIconDesignerLocalization.string("Icon Documents"),
                    systemImage: "doc.text",
                    order: order
                ) {
                    AppIconDesignerRailView()
                },
            ])
        } else {
            Self.logger.error("\(Self.t) RailViewProviding not found")
        }

        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            let pluginID = id
            let railWidthStore = kernel
                .resolveProvider((any StorageProviding).self)
                .map { storage in
                    FileRailViewWidthStore(
                        fileURL: storage
                            .pluginDataDirectory(for: pluginID)
                            .appendingPathComponent("rail-view-width.plist", isDirectory: false)
                    )
                }
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: name,
                    systemImage: "app.dashed",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        toolbar?.setVisibleCategories([.global, .chat, .design])
                        rootView?.setContentHeaderViewHidden(true)
                        railView?.setVisibleTabID(Self.railTabID)
                        railView?.activateWidthProfile(
                            ownerID: pluginID,
                            recommended: RailViewWidth(minWidth: 260, idealWidth: 320, maxWidth: 460),
                            store: railWidthStore
                        )
                        IconDocumentStore.shared.reload()
                        contentView?.setContentView(AnyView(DesignerView()))
                        chat?.setVisible(true)
                        chat?.setContextActive(true)
                        chat?.setActiveContext(chatContext)
                    } else {
                        toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                        rootView?.setContentHeaderViewHidden(false)
                        chat?.setActiveContext(nil)
                        railView?.deactivateWidthProfile(ownerID: pluginID)
                    }
                },
            ])
        } else {
            IconDocumentStore.shared.reload()
            contentView?.setContentView(AnyView(DesignerView()))
            chat?.setVisible(true)
            chat?.setContextActive(true)
            chat?.setActiveContext(chatContext)
            railView?.activateWidthProfile(
                ownerID: id,
                recommended: RailViewWidth(minWidth: 260, idealWidth: 320, maxWidth: 460),
                store: kernel
                    .resolveProvider((any StorageProviding).self)
                    .map { storage in
                        FileRailViewWidthStore(
                            fileURL: storage
                                .pluginDataDirectory(for: id)
                                .appendingPathComponent("rail-view-width.plist", isDirectory: false)
                        )
                    }
            )
        }
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: false)
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: false)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 撤回注册的 Agent 工具。
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }

        kernel.resolveProvider((any RailViewProviding).self)?
            .removeTabs(ids: [Self.railTabID])

        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        if wasActive {
            kernel.resolveProvider((any ChatSectionProviding).self)?.setActiveContext(nil)
        }
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any RailViewProviding).self)?.deactivateWidthProfile(ownerID: id)
            kernel.resolveProvider((any RootViewProviding).self)?.setContentHeaderViewHidden(false)
            kernel.resolveProvider((any RailViewProviding).self)?.setVisibleCategories(Set(RailViewCategory.allCases))
        }
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }

        IconDesignerRuntime.reset()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: true)
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    // MARK: - Agent Tools

    /// 本插件贡献的 Agent 工具（复刻旧版 AppIconDesignerPlugin.agentTools）。
    public static let agentTools: [any SuperAgentTool] = [
        ListIconDocumentsTool(),
        CreateIconDocumentTool(),
        ApplyIconPresetTool(),
        LoadIconDocumentTool(),
        SaveIconDocumentTool(),
        SetIconBackgroundTool(),
        AddIconShapeTool(),
        UpdateIconShapeTool(),
        UpdateIconLayerTool(),
        LintIconDocumentTool(),
        PreviewIconTool(),
        ExportIconSVGTool(),
        ExportAppIconTool(),
        RegisterAppIconArtifactTool(),
        ReviewIconTool(),
    ]
}
