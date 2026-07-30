import AppKit
import Combine
import LumiKernel
import LumiUI
import os
import SwiftUI

@MainActor
public final class ConversationListPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-list"
    public let name = "Conversation List"
    public let order = 76
    public let policy: LumiPluginPolicy = .alwaysOn

    public static let verbose = true
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list")

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        if let storage = kernel.storage {
            ConversationListRuntimeBridge.shared.storageDirectory = storage.pluginDataDirectory(for: "ConversationList")
        } else {
            ConversationListRuntimeBridge.shared.storageDirectory = ConversationListRuntimeBridge.defaultStorageDirectory
        }

        // 桥接 kernel.conversations 到 tools RuntimeBridge。
        // 注意 SetConversationProjectLumiTool 暂未启用 —— 等 ConversationManaging
        // 协议扩展 setConversationProjectPath(...) 之后再补。
        if let conversations = kernel.conversations {
            ConversationListToolRuntimeBridge.conversations = conversations
        }
    }

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            CreateNewConversationLumiTool(),
            DeleteConversationLumiTool(),
            GetRecentConversationsLumiTool(),
            GetConversationCountLumiTool(),
        ]
    }

    // toolbar item 由 titleToolbarItems(kernel:) 声明式提供,不在此处注册。

    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "chats",
                title: "Chats",
                systemImage: "message.fill"
            ) {
                ConversationListView(kernel: kernel)
            },
        ]
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).conversation-list",
                title: "Chats",
                placement: .trailing,
                order: 200
            ) {
                ConversationListToolbarButton(kernel: kernel)
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
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
