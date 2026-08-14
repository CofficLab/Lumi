import KernelLumi
import LumiUI
import SwiftUI

@MainActor
public final class ResumeDesignerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.resume-designer"

    /// 本插件 rail 面板的稳定标识（注册为 `PanelRailTabItem.id`）。
    public nonisolated static let railTabID = "resume-designer.resumes"

    public var name: String { ResumeLocalization.string("Resume Designer") }
    public let order = 81
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .beta
    public var pluginDescription: String {
        ResumeLocalization.string("Agent-built HTML resumes with print-optimized PDF and PNG export.")
    }

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        try await ResumeDesignerOnBootHook().execute(kernel)
    }

    public func onReady(kernel: KernelLumi) async throws {
        try await ResumeDesignerOnReadyHook().execute(kernel)
    }

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
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

    public func willSendToLLM(kernel: KernelLumi, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        await ResumeDesignerWillSendToLLMHook().execute(kernel: kernel, messages: messages)
    }

    // MARK: - Prompt Suggestions

    /// 贡献聊天起始提示词，供消息列表空态展示。
    public func promptSuggestions(kernel: KernelLumi) -> [LumiPromptSuggestion] {
        [
            LumiPromptSuggestion(
                id: "\(id).create",
                title: ResumeLocalization.string("Prompt.Suggestion.Create"),
                systemImage: "doc.badge.gearshape",
                action: .activateRailTab(id: Self.railTabID, viewContainerID: self.id)
            )
        ]
    }

    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: Self.railTabID,
                title: ResumeLocalization.string("Resumes"),
                systemImage: "doc.text",
                visibility: .viewContainer(id: id)
            ) {
                ResumeRailView()
            },
        ]
    }

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "doc.badge.gearshape",
                supportsProject: true,
                railVisibility: .alwaysVisible,
                chatVisibility: .alwaysVisible,
                panelHeaderVisibility: .unsupported,
                panelBodyVisibility: .alwaysVisible,
                panelBottomVisibility: .unsupported
            ) {
                ResumeDesignerView()
            },
        ]
    }

    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(ResumeAboutView())
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: name,
                placement: .center,
                order: 0
            ) {
                ResumeDesignerToolbarTitleView(containerID: self.id, kernel: kernel, title: self.name)
            },
        ]
    }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {
        if containerID == id { WorkspaceStore.shared.reload() }
    }
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
