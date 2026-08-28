import KitAgentTool
import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderToolManager
import ProviderPromptSuggestion
import SwiftUI
import KitSuperLog
import os

/// KernelCore 版本的 Resume Designer 插件。
///
/// 由旧版 `Plugins/ResumeDesignerPlugin`（KernelLumi / LumiPlugin 架构）复刻而来，
/// 参考 `PluginAppIconDesigner` 的装配方式：onBoot 注册 Agent 工具、Rail 标签、
/// ActivityBar 入口与 Docs 文档；onShutdown 全部撤回。
@MainActor
public final class ResumeDesignerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.resume-designer", category: "ResumeDesigner")
    public let id = "com.coffic.lumi.plugin.resume-designer"
    public let order = 81
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.resume-designer",
        name: "Resume Designer",
        description: "",
        category: .design,
        stage: .stable,
        policy: .disabledByDefault
    )

    /// 本插件 rail 面板的稳定标识（注册为 `RailTabItem.id`）。
    public static let railTabID = "resume-designer.resumes"

    public var name: String {
        ResumeDesignerLocalization.string("Resume Designer")
    }

    public init() {}

    private var promptSuggestion: PromptSuggestion {
        PromptSuggestion(id: "\(id).create", title: ResumeDesignerLocalization.string("Prompt.Suggestion.Create"), order: order * 1_000, systemImage: "doc.badge.gearshape", action: .activateRailTab(id: Self.railTabID))
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
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        ResumeDesignerRuntime.configure(kernel: kernel, pluginID: id)

        // 注册 Agent 工具到 ToolManagerProviding
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }

        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)

        // 必须先注册 Rail，再注册 ActivityBar，确保首次激活回调能找到贡献。
        railView?.addTabs([
            RailTabItem(
                id: Self.railTabID,
                category: .design,
                title: ResumeDesignerLocalization.string("Resumes"),
                systemImage: "doc.text",
                order: order
            ) {
                ResumeRailView()
            },
        ])

        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: name,
                    systemImage: "doc.badge.gearshape",
                    order: order,
                    ownerPluginID: id
                ) { activeItemID in
                    guard activeItemID == entryID else { return }
                    railView?.setVisibleCategories([.design])
                    WorkspaceStore.shared.reload()
                    contentView?.setContentView(AnyView(DesignerView()))
                },
            ])
        } else {
            WorkspaceStore.shared.reload()
            contentView?.setContentView(AnyView(DesignerView()))
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
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any RailViewProviding).self)?.setVisibleCategories(Set(RailViewCategory.allCases))
        }
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }

        ResumeDesignerRuntime.reset()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: true)
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    // MARK: - Agent Tools

    /// 本插件贡献的 Agent 工具（复刻旧版 ResumeDesignerPlugin.agentTools）。
    public static let agentTools: [any SuperAgentTool] = [
        ListResumesTool(),
        CreateResumeTool(),
        ReadResumeTool(),
        ReadResumeHTMLTool(),
        ReplaceResumeHTMLTool(),
        PatchResumeHTMLTool(),
        ImportResumeAssetTool(),
        LintResumeTool(),
        PreviewResumePageTool(),
        ExportResumeTool(),
    ]
}
