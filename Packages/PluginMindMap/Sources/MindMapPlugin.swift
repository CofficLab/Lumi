import KernelLumi
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// 思维导图插件
///
/// 提供原生 SwiftUI 思维导图编辑能力，并通过 agent tools 让全局聊天的 Agent
/// 创建/扩展/调整思维导图。架构与 `AppIconDesignerPlugin` 同构：
/// 一个画布 view container + 一批 agent tools + `MindMapStore` 单例共享状态 +
/// `willSendToLLM` 注入使用指南。不贡献任何 chat section。
@MainActor
public final class MindMapPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🧠"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.mind-map"
    )

    /// 本插件思维导图 rail 面板的稳定标识（注册为 `PanelRailTabItem.id`，并用于
    /// 提示词动作 `.activateRailTab` 定位到该面板）。
    public nonisolated static let railTabID = "mind-map.documents"

    public let id = "com.coffic.lumi.plugin.mind-map"
    public var name: String { MindMapLocalization.string("Mind Map", "思维导图") }
    public var pluginDescription: String {
        MindMapLocalization.string(
            "Create and edit mind maps with AI assistance via native canvas and agent tools.",
            "原生画布 + Agent 工具驱动的思维导图编辑器。"
        )
    }

    public let order = 81
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        MindMapRuntime.configure(kernel: kernel)
    }

    public func onReady(kernel: KernelLumi) async throws {
        // 依赖其他服务的异步初始化在此进行；本插件目前无需额外处理。
    }

    // MARK: - Agent Tools

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
            ListMindMapsTool(),
            CreateMindMapTool(),
            AddChildNodeTool(),
            UpdateNodeTool(),
            DeleteNodeTool(),
            MoveNodeTool(),
            SaveMindMapTool(),
            LoadMindMapTool(),
            ExportMindMapTool(),
            ImportOutlineTool(),
        ]
    }

    public func willSendToLLM(kernel: KernelLumi, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        await MindMapWillSendToLLMHook().execute(kernel: kernel, messages: messages)
    }

    // MARK: - Prompt Suggestions

    /// 贡献聊天起始提示词，点击后激活本容器及其思维导图 rail 面板，并把提示词送入全局聊天。
    public func promptSuggestions(kernel: KernelLumi) -> [LumiPromptSuggestion] {
        [
//            LumiPromptSuggestion(
//                id: "\(id).create",
//                title: MindMapLocalization.string("Create a mind map", "创建一个思维导图"),
//                systemImage: "brain.head.profile",
//                action: .activateRailTab(id: Self.railTabID, viewContainerID: id)
//            ),
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
                MindMapToolbarTitleView(containerID: self.id, kernel: kernel, title: self.name)
            },
        ]
    }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: Self.railTabID,
                title: MindMapLocalization.string("Mind Maps", "思维导图"),
                systemImage: "doc.text",
                visibility: .viewContainer(id: id)
            ) {
                MindMapRailView()
            },
        ]
    }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "brain.head.profile",
                supportsProject: true,
                railVisibility: .alwaysVisible,
                chatVisibility: .alwaysVisible,
                panelHeaderVisibility: .unsupported,
                panelBodyVisibility: .alwaysVisible,
                panelBottomVisibility: .unsupported
            ) {
                MindMapView()
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
        AnyView(MindMapAboutView())
    }

    public func pluginManualView(kernel: KernelLumi) -> AnyView? {
        AnyView(MindMapManualView())
    }

    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {
        if containerID == id { MindMapStore.shared.reload() }
    }
}
