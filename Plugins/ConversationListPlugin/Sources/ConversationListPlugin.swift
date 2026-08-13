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
    private let railTabController: ConversationRailTabController

    public init() {
        let attentionStore = ConversationAttentionStore()
        let sortStabilizer = ConversationSortStabilizer()
        self.attentionStore = attentionStore
        self.sortStabilizer = sortStabilizer
        // `chats` / `project-chats` 均不再静态注册：由控制器按对话存在情况动态注册/注销——
        // 全库无对话时隐藏 `chats` 主入口；当前项目无对话（或全库仅单项目）时隐藏
        // `project-chats`。`order` 与插件一致以保持排序。
        railTabController = ConversationRailTabController(
            attentionStore: attentionStore,
            sortStabilizer: sortStabilizer,
            order: order
        )
    }

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        railTabController.start(kernel: kernel)
    }

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
            GetRecentConversationsTool(),
        ]
    }

    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        // `chats` 与 `project-chats` 均改为由 `ConversationRailTabController` 动态注册，
        // 此处不再静态返回，避免与控制器的 register/unregister 产生所有权冲突。
        []
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
