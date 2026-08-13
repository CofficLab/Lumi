import KernelLumi
import LumiUI
import os
import SwiftUI

@MainActor
public final class MemoryPlugin: LumiPlugin {
    public nonisolated static let emoji = "🧠"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.memory"
    )

    /// 插件配置（由 onReady 设置存储目录）
    public nonisolated(unsafe) static var config: MemoryPluginConfig = .default

    public let id = "com.coffic.lumi.plugin.memory"
    public var name: String {
        LumiPluginLocalization.string("Memory", bundle: .module)
    }
    public let order = 4
    public let policy: LumiPluginPolicy = .alwaysOn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .beta
    public let pluginDescription = "Agent memory system for persistent context across conversations."

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        try await MemoryOnReadyHook().execute(kernel)
    }

    public func willSendToLLM(
        kernel: KernelLumi,
        messages: [LumiChatMessage]
    ) async -> [LumiChatMessage] {
        await MemoryWillSendToLLMHook().execute(kernel: kernel, messages: messages)
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
            SaveMemoryTool(),
            ListMemoriesTool(),
            RecallMemoryTool(),
            DeleteMemoryTool(),
        ]
    }
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
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
        [
            SettingsTabItem(
                id: "\(id).settings",
                title: LumiPluginLocalization.string("Memory", bundle: .module),
                systemImage: "brain",
                order: order
            ) {
                MemorySettingsView()
            },
        ]
    }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {
        await MemoryTurnFinishedHook().execute(
            kernel: kernel,
            conversationID: conversationID,
            reason: reason
        )
    }
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
