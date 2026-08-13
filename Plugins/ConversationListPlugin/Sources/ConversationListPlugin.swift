import AppKit
import Combine
import KernelLumi
import LumiUI
import os
import SwiftUI

@MainActor
public final class ConversationListPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-list"
    public var name: String {
        LumiPluginLocalization.string("Conversation List", bundle: .module)
    }
    public let order = 76
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    public static let verbose = false
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list")
    public let attentionStore: ConversationAttentionStore
    public let sortStabilizer: ConversationSortStabilizer
    private let projectChatsTabController: ProjectChatsTabController

    public init() {
        let attentionStore = ConversationAttentionStore()
        let sortStabilizer = ConversationSortStabilizer()
        self.attentionStore = attentionStore
        self.sortStabilizer = sortStabilizer
        // `project-chats` 不再静态注册：由控制器按「当前项目是否有对话」动态注册/注销，
        // 当前项目 0 对话时彻底隐藏入口。`order` 与插件一致以保持与 `chats` 同序。
        projectChatsTabController = ProjectChatsTabController(
            attentionStore: attentionStore,
            sortStabilizer: sortStabilizer,
            order: order
        )
    }

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        projectChatsTabController.start(kernel: kernel)
    }

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
            GetRecentConversationsTool(),
        ]
    }

    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        let attentionStore = self.attentionStore
        let sortStabilizer = self.sortStabilizer
        // `project-chats` 已改为由 `ProjectChatsTabController` 动态注册，
        // 此处仅保留始终可见的 `chats`。
        return [
            PanelRailTabItem(
                id: "chats",
                title: LumiPluginLocalization.string("Chats", bundle: .module),
                systemImage: "message.fill",
                requiresChatSupport: true
            ) {
                RailView(kernel: kernel, attentionStore: attentionStore, sortStabilizer: sortStabilizer)
            },
        ]
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        let attentionStore = self.attentionStore
        let sortStabilizer = self.sortStabilizer
        return [
            LumiTitleToolbarItem(
                id: "\(id).conversation-list",
                title: LumiPluginLocalization.string("Chats", bundle: .module),
                placement: .trailing,
                order: 200
            ) {
                ToolbarButton(kernel: kernel, attentionStore: attentionStore, sortStabilizer: sortStabilizer)
            },
        ]
    }

    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {
        if kernel.conversations?.selectedConversationID == conversationID {
            attentionStore.markRead(conversationID: conversationID)
        } else {
            attentionStore.markNeedsAttention(conversationID: conversationID)
        }
    }

    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
