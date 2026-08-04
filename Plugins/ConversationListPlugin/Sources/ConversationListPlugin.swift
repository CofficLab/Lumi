import AppKit
import Combine
import LumiKernel
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

    public static let verbose = false
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list")
    public let attentionStore: ConversationAttentionStore
    private let selectedProjectHook = OnConversationSelectedHook()

    public init() {
        attentionStore = ConversationAttentionStore()
    }

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        // 放在 onReady 而不是 onBoot：onBoot 只保证自己注册顺序里的服务可用，
        // onReady 才是「所有插件的 onBoot 已完成」之后，更稳。
        // 这里真正依赖的是 kernel.conversations（由 order=7 的
        // ConversationManagerPlugin 在我们 order=76 之前注册），实际在
        // onBoot 阶段就已可用，但放 onReady 跟项目里其他 Hook 一致。
        selectedProjectHook.attach(kernel: kernel)
    }

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            GetRecentConversationsTool(),
        ]
    }

    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        let attentionStore = self.attentionStore
        return [
            PanelRailTabItem(
                id: "chats",
                title: "Chats",
                systemImage: "message.fill"
            ) {
                ListView(kernel: kernel, attentionStore: attentionStore)
            },
            PanelRailTabItem(
                id: "project-chats",
                title: "Project",
                systemImage: "folder.fill"
            ) {
                ListView(kernel: kernel, attentionStore: attentionStore, scopeToCurrentProject: true)
            },
        ]
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
        let attentionStore = self.attentionStore
        return [
            LumiTitleToolbarItem(
                id: "\(id).conversation-list",
                title: "Chats",
                placement: .trailing,
                order: 200
            ) {
                ToolbarButton(kernel: kernel, attentionStore: attentionStore)
            },
        ]
    }

    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {
        if kernel.conversations?.selectedConversationID == conversationID {
            attentionStore.markRead(conversationID: conversationID)
        } else {
            attentionStore.markNeedsAttention(conversationID: conversationID)
        }
    }

    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
