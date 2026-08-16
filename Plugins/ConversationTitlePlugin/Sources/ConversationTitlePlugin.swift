import Foundation
import SwiftUI
import KernelLumi
import SuperLogKit
import os

@MainActor
public final class ConversationTitlePlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-title")
    nonisolated public static let emoji = "✏️"
    public static let verbose = false

    public let id = "com.coffic.lumi.plugin.conversation-title"
    public var name: String {
        LumiPluginLocalization.string("Conversation Title", bundle: .module)
    }
    public let order = 77
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta
    private var autoTitleService: AutoConversationTitleService?

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        autoTitleService = AutoConversationTitleService(kernel: kernel)
        if Self.verbose {
            Self.logger.info("\(Self.t)Registered conversation title header")
        }
    }

    public func willSendToLLM(kernel: KernelLumi, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        messages
    }

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        Self.makeAgentTools(kernel: kernel)
    }

    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] {
        if Self.verbose {
            Self.logger.info("\(Self.t)Providing chat section header item")
        }
        return [
            ChatSectionHeaderItem(id: id) {
                ConversationTitleHeaderView(kernel: kernel)
            }
        ]
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
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
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}

    @MainActor
    public static func agentTools(lumiCore: Any) -> [any LumiAgentTool] {
        if let kernel = lumiCore as? KernelLumi {
            return makeAgentTools(kernel: kernel)
        }
        return [ConversationTitleUpdateTool()]
    }

    @MainActor
    private static func makeAgentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        guard let conversations = kernel.conversations else {
            return []
        }
        return [
            ConversationTitleUpdateTool(conversations: conversations)
        ]
    }
}
