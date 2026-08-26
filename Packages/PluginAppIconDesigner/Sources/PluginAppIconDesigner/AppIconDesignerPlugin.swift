import KernelCore
import KitAgentTool
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderPromptSuggestion
import ProviderRailView
import ProviderToolManager
import ProviderWorkspace
import SwiftUI

/// KernelCore 版本的 App Icon 设计器插件。
@MainActor
public final class AppIconDesignerPlugin: SuperPlugin {
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
                railTabID: Self.railTabID,
                viewContainerID: id
            )
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
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        IconDesignerRuntime.configure(kernel: kernel, pluginID: id)

        // 注册 Agent 工具到 ToolManagerProviding
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }

        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let workspace = kernel.resolveProvider((any WorkspaceProviding).self)

        workspace?.registerContainer(
            WorkspaceContainer(
                id: id,
                title: name,
                systemImage: "app.dashed",
                order: order,
                railVisibility: .alwaysVisible,
                chatVisibility: .alwaysVisible,
                panelHeaderVisibility: .unsupported,
                panelBodyVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ),
            ownerPluginID: id
        )

        // 必须先注册 Rail，再注册 ActivityBar，确保首次激活回调能找到贡献。
        railView?.addTabs([
            RailTabItem(
                id: Self.railTabID,
                groupID: id,
                title: AppIconDesignerLocalization.string("Icon Documents"),
                systemImage: "doc.text",
                order: order
            ) {
                AppIconDesignerRailView()
            },
        ])

        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: name,
                    systemImage: "app.dashed",
                    order: order,
                    ownerPluginID: id
                ) { activeItemID in
                    guard activeItemID == entryID else { return }
                    IconDocumentStore.shared.reload()
                    contentView?.setContentView(AnyView(DesignerView()))
                    chat?.setVisible(true)
                    chat?.setContextActive(true)
                    railView?.activateGroup(id: self.id)
                    workspace?.activateContainer(id: self.id)
                },
            ])
        } else {
            IconDocumentStore.shared.reload()
            contentView?.setContentView(AnyView(DesignerView()))
            chat?.setVisible(true)
            chat?.setContextActive(true)
            railView?.activateGroup(id: id)
            workspace?.activateContainer(id: id)
        }

        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { DesignerAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { DesignerManualView() })
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
        kernel.resolveProvider((any WorkspaceProviding).self)?
            .unregisterContainers(ownerPluginID: id)

        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        activityBar?.removeItems(ids: ["\(id).entry"])
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }

        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        IconDesignerRuntime.reset()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: true)
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
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
