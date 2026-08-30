import KitAgentTool
import KernelCore
import ProviderActivityBar
import ProviderToolbar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderStorage
import ProviderRootView
import ProviderToolManager
import ProviderPromptSuggestion
import SwiftUI
import KitSuperLog
import os

/// KernelCore 版本的 App Store 促销图设计器插件。
///
/// 由旧版 `Plugins/AppStorePromoDesignerPlugin`（KernelLumi / LumiPlugin）复刻而来，
/// 形态对齐 `PluginAppIconDesigner`：SuperPlugin + SuperAgentTool + Provider 注册表。
@MainActor
public final class AppStorePromoDesignerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.app-store-promo-designer", category: "AppStorePromoDesigner")
    public let id = "com.coffic.lumi.plugin.app-store-promo-designer"
    public let order = 80
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.app-store-promo-designer",
        name: "App Store Promo Designer",
        description: "",
        category: .design,
        stage: .stable,
        policy: .disabledByDefault
    )

    public static let railTabID = "app-store-promo.tasks"

    public var name: String {
        PromoLocalization.string("App Store Promo Designer")
    }

    public init() {}

    private var promptSuggestion: PromptSuggestion {
        PromptSuggestion(
            id: "\(id).create",
            title: PromoLocalization.string("Prompt.Suggestion.Create"),
            order: order * 1_000,
            systemImage: "photo.artframe",
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
            docs.addAbout(DocsEntry(id: id, name: name) { PromoAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { PromoManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        PromoDesignerRuntime.configure(kernel: kernel, pluginID: id)

        // 注册 Agent 工具到 ToolManagerProviding。
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }

        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let chatContext = ChatContext(
            id: id,
            title: name,
            subtitle: metadata.description.isEmpty ? nil : metadata.description,
            systemImage: "photo.artframe"
        )
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let chatWidthStore = kernel
            .resolveProvider((any StorageProviding).self)
            .map { storage in
                FileChatSectionWidthStore(
                    fileURL: storage
                        .pluginDataDirectory(for: id)
                        .appendingPathComponent("chat-section-width.plist", isDirectory: false)
                )
            }

        // 必须先注册 Rail，再注册 ActivityBar，确保首次激活回调能找到贡献。
        railView?.addTabs([
            RailTabItem(
                id: Self.railTabID,
                category: .design,
                title: PromoLocalization.string("Promo Tasks"),
                systemImage: "photo.stack",
                order: order
            ) {
                PromoRailView()
            },
        ])

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
                    systemImage: "photo.artframe",
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
                        WorkspaceStore.shared.reload()
                        contentView?.setContentView(AnyView(PromoDesignerView()))
                        chat?.setVisible(true)
                        chat?.setContextActive(true)
                        chat?.setActiveContext(chatContext)
                        chat?.activateWidthProfile(
                            ownerID: pluginID,
                            recommended: ChatSectionWidth(minWidth: 300, idealWidth: 360, maxWidth: 560),
                            store: chatWidthStore
                        )
                    } else {
                        toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                        rootView?.setContentHeaderViewHidden(false)
                        chat?.setActiveContext(nil)
                        chat?.deactivateWidthProfile(ownerID: pluginID)
                        railView?.deactivateWidthProfile(ownerID: pluginID)
                    }
                },
            ])
        } else {
            WorkspaceStore.shared.reload()
            contentView?.setContentView(AnyView(PromoDesignerView()))
            chat?.setVisible(true)
            chat?.setContextActive(true)
            chat?.setActiveContext(chatContext)
            chat?.activateWidthProfile(
                ownerID: id,
                recommended: ChatSectionWidth(minWidth: 300, idealWidth: 360, maxWidth: 560),
                store: chatWidthStore
            )
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
            kernel.resolveProvider((any ChatSectionProviding).self)?.deactivateWidthProfile(ownerID: id)
            kernel.resolveProvider((any RailViewProviding).self)?.deactivateWidthProfile(ownerID: id)
            kernel.resolveProvider((any RootViewProviding).self)?.setContentHeaderViewHidden(false)
            kernel.resolveProvider((any RailViewProviding).self)?.setVisibleCategories(Set(RailViewCategory.allCases))
        }
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }

        PromoDesignerRuntime.reset()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: true)
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    // MARK: - Agent Tools

    /// 本插件贡献的 Agent 工具（复刻旧版 PromoDesignerPlugin.agentTools）。
    public static let agentTools: [any SuperAgentTool] = [
        ListPromoTasksTool(),
        CreatePromoTaskTool(),
        ReadPromoTaskTool(),
        CreatePromoImageTool(),
        AddPromoImageLocalizationTool(),
        ReadPromoHTMLTool(),
        ReplacePromoHTMLTool(),
        PatchPromoHTMLTool(),
        ImportPromoAssetTool(),
        PreviewPromoImageTool(),
        LintPromoTaskTool(),
        ExportPromoTaskTool(),
        ReviewPromoImageTool(),
    ]
}
