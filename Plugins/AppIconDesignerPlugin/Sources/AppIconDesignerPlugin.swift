import KernelLumi
import LumiUI
import os
import SuperLogKit
import SwiftUI

@MainActor
public final class AppIconDesignerPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🎨"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.app-icon-designer"
    )

    public let id = "com.coffic.lumi.plugin.app-icon-designer"

    /// 本插件 rail 面板的稳定标识（注册为 `PanelRailTabItem.id`）。
    public nonisolated static let railTabID = "app-icon-designer.documents"

    public var name: String {
        AppIconDesignerLocalization.string("AppIconDesigner Name")
    }

    public let order = 79
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .beta
    public var pluginDescription: String {
        AppIconDesignerLocalization.string("Design app icons with shapes, layers, and export capabilities.")
    }

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        IconDesignerRuntime.configure(kernel: kernel)
    }

    public func onReady(kernel: KernelLumi) async throws {
        if Self.verbose {
            Self.logger.info("🎨 AppIconDesigner 插件初始化完成")
        }
    }

    // MARK: - Agent Tools

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
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

    public func willSendToLLM(kernel: KernelLumi, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        await IconDesignerWillSendToLLMHook().execute(kernel: kernel, messages: messages)
    }

    // MARK: - Prompt Suggestions

    /// 贡献聊天起始提示词，供消息列表空态展示。
    ///
    /// 每条都声明 `.activateViewContainer(id)` 动作——点击时（必要时先启用本插件并重建
    /// 贡献注册其容器）会自动激活图标设计面板，再发送提示词。
    public func promptSuggestions(kernel: KernelLumi) -> [LumiPromptSuggestion] {
        [
            LumiPromptSuggestion(
                id: "\(id).design",
                title: AppIconDesignerLocalization.string("Prompt.Suggestion.Design"),
                systemImage: "app.dashed",
                action: .activateRailTab(id: Self.railTabID, viewContainerID: self.id)
            )
        ]
    }

    // MARK: - LumiPlugin stubs

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
                AppIconDesignerToolbarTitleView(containerID: self.id, kernel: kernel, title: self.name)
            },
        ]
    }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: Self.railTabID,
                title: AppIconDesignerLocalization.string("Icon Documents"),
                systemImage: "doc.text",
                visibility: .viewContainer(id: id)
            ) {
                AppIconDesignerRailView()
            },
        ]
    }

    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "app.dashed",
                supportsProject: true,
                railVisibility: .alwaysVisible,
                chatVisibility: .alwaysVisible,
                panelHeaderVisibility: .unsupported,
                panelBodyVisibility: .alwaysVisible,
                panelBottomVisibility: .unsupported
            ) {
                DesignerView()
            },
        ]
    }

    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(DesignerAboutView())
    }

    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {
        if containerID == id { IconDocumentStore.shared.reload() }
    }
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
