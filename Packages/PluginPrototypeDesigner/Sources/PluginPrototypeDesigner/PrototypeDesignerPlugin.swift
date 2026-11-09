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
import ProviderSkill
import ProviderAgentRules
import ProviderToolManager
import ProviderPromptSuggestion
import ProviderProject
import SwiftUI
import LumiLoggingKit
import os

/// 产品原型图设计器插件。
///
/// 形态对齐 `PluginAppStorePromoDesigner`：SuperPlugin + SuperAgentTool + Provider 注册表。
/// 画面用 HTML/CSS 承载，`manifest.json` 存结构与跳转索引；渲染复用
/// `KitHTMLPreview` 的 `WKWebView` 管线。
@MainActor
public final class PrototypeDesignerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.prototype-designer", category: "PrototypeDesigner")
    public let id = "com.coffic.lumi.plugin.prototype-designer"
    public let order = 82
    private var projectObserver: PrototypeDesignerProjectObserver?
    private let workspace = WorkspaceStore.shared
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.prototype-designer",
        name: PrototypeLocalization.string("Prototype Designer"),
        description: PrototypeLocalization.string("Sketch product prototypes as connected HTML screens."),
        category: .design,
        stage: .stable,
        policy: .disabledByDefault
    )

    public static let railTabID = "prototype.screens"

    public var name: String {
        PrototypeLocalization.string("Prototype Designer")
    }

    public init() {}

    private var promptSuggestion: PromptSuggestion {
        PromptSuggestion(
            id: "\(id).create",
            title: PrototypeLocalization.string("Prompt.Suggestion.Create"),
            order: order * 1_000,
            systemImage: "rectangle.on.rectangle.angled",
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
            docs.addAbout(DocsEntry(id: id, name: name) { PrototypeAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { PrototypeManualView() })
        }
    }

    // MARK: - Agent 贡献注册 / 撤回

    private func registerAgentTools(kernel: KernelCoreContainer) {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else { return }
        for tool in Self.agentTools {
            toolManager.add(ConversationScopedPrototypeTool(tool), pluginID: id)
        }
    }

    private func removeAgentTools(kernel: KernelCoreContainer) {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else { return }
        for tool in Self.agentTools {
            toolManager.remove(id: tool.name)
        }
    }

    private func registerSkillContributor(kernel: KernelCoreContainer) {
        guard let skillProvider = kernel.resolveProvider((any SkillProviding).self) else { return }
        guard !skillProvider.isProviderRegistered(providerID: id) else { return }
        let contributor = PrototypeDesignerSkillContributor(providerID: id)
        skillProvider.addProvider(contributor)
        Self.logger.info("\(Self.t)Contributed \(contributor.allSkills.count) skill(s) via SkillProviding")
    }

    private func removeSkillContributor(kernel: KernelCoreContainer) {
        kernel.resolveProvider((any SkillProviding).self)?.removeProvider(providerID: id)
    }

    private func registerRuleContributor(kernel: KernelCoreContainer) {
        guard let ruleProvider = kernel.resolveProvider((any AgentRuleProviding).self) else { return }
        guard !ruleProvider.isProviderRegistered(providerID: id) else { return }
        let contributor = PrototypeDesignerRuleContributor(providerID: id)
        ruleProvider.addProvider(contributor)
        Self.logger.info("\(Self.t)Contributed \(contributor.allRules.count) rule(s) via AgentRuleProviding")
    }

    private func removeRuleContributor(kernel: KernelCoreContainer) {
        kernel.resolveProvider((any AgentRuleProviding).self)?.removeProvider(providerID: id)
    }

    private func startProjectObserver(kernel: KernelCoreContainer) {
        projectObserver?.cancel()
        projectObserver = kernel.resolveProvider((any ProjectProviding).self).map { project in
            PrototypeDesignerProjectObserver(project: project) { path in
                PrototypeDesignerRuntime.updateProjectStorageDirectory(projectPath: path)
            }
        }
    }

    private func stopProjectObserver() {
        projectObserver?.cancel()
        projectObserver = nil
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        PrototypeDesignerRuntime.configure(kernel: kernel)
        startProjectObserver(kernel: kernel)

        // 注册 Agent 工具到 ToolManagerProviding。
        registerAgentTools(kernel: kernel)

        // 注册 Skill 贡献者到 SkillProviding
        registerSkillContributor(kernel: kernel)

        // 注册 Agent Rule 贡献者。
        registerRuleContributor(kernel: kernel)

        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let chatContext = ChatContext(
            id: id,
            title: name,
            subtitle: metadata.description.isEmpty ? nil : metadata.description,
            systemImage: "rectangle.on.rectangle.angled"
        )
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let makeDesignerView: () -> AnyView = { [weak rootView] in
            AnyView(
                PrototypeDesignerView(
                    workspace: self.workspace,
                    onProjectAvailabilityChanged: { [weak rootView] hasProjects in
                        rootView?.setRailViewVisible(hasProjects)
                    }
                )
            )
        }
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
                title: PrototypeLocalization.string("Prototypes"),
                systemImage: "rectangle.on.rectangle.angled",
                order: order
            ) {
                PrototypeRailView(workspace: self.workspace)
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
                    systemImage: "rectangle.on.rectangle.angled",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        toolbar?.setVisibleCategories([.global, .project, .chat, .design])
                        rootView?.setContentHeaderViewHidden(true)
                        railView?.setVisibleTabID(Self.railTabID)
                        railView?.activateWidthProfile(
                            ownerID: pluginID,
                            recommended: RailViewWidth(minWidth: 260, idealWidth: 320, maxWidth: 460),
                            store: railWidthStore
                        )
                        self.workspace.reload()
                        rootView?.setRailViewVisible(!self.workspace.projects.isEmpty)
                        contentView?.setContentView(makeDesignerView())
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
                        railView?.setVisibleCategories(Set(RailViewCategory.allCases))
                        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
                    }
                },
            ])
        } else {
            workspace.reload()
            rootView?.setRailViewVisible(!workspace.projects.isEmpty)
            contentView?.setContentView(makeDesignerView())
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
        // 禁用期间退出的项目观察者与运行时状态需要恢复。
        PrototypeDesignerRuntime.configure(kernel: kernel)
        startProjectObserver(kernel: kernel)
        registerAgentTools(kernel: kernel)
        registerSkillContributor(kernel: kernel)
        registerRuleContributor(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        removeAgentTools(kernel: kernel)
        removeSkillContributor(kernel: kernel)
        removeRuleContributor(kernel: kernel)

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
            kernel.resolveProvider((any RootViewProviding).self)?.setRailViewVisible(
                kernel.resolveProvider((any RailViewProviding).self)?.hasVisibleTabs ?? false
            )
        }
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }

        stopProjectObserver()
        PrototypeDesignerRuntime.reset()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: true)
        // 禁用的插件不能再把项目/屏幕/HTML 工具暴露给后续 Agent 回合。
        removeAgentTools(kernel: kernel)
        removeSkillContributor(kernel: kernel)
        removeRuleContributor(kernel: kernel)
        stopProjectObserver()
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    // MARK: - Agent Tools

    /// 本插件贡献的 Agent 工具。
    public static let agentTools: [any SuperAgentTool] = [
        // 项目
        ListPrototypeProjectsTool(),
        CreatePrototypeProjectTool(),
        ReadPrototypeProjectTool(),
        UpdatePrototypeProjectTool(),
        DeletePrototypeProjectTool(),
        // 屏幕
        AddPrototypeScreenTool(),
        DuplicatePrototypeScreenTool(),
        DeletePrototypeScreenTool(),
        ReorderPrototypeScreensTool(),
        SetPrototypeStartScreenTool(),
        // HTML 编辑
        ReadPrototypeHTMLTool(),
        ReplacePrototypeHTMLTool(),
        PatchPrototypeHTMLTool(),
        // 预览 / 资源 / 交付
        PreviewPrototypeScreenTool(),
        ImportPrototypeAssetTool(),
        LintPrototypeTool(),
        ExportPrototypeTool(),
    ]
}
