import Foundation
import SwiftUI
import LumiKernel
import os
import SuperLogKit

/// Message Streaming Plugin
///
/// Registers a `MessageStreaming` implementation (`MessageStreamingStore`) with the kernel.
/// 该 store 持有"当前正在流式的临时 assistant 行"，由 `AgentTurnRunner` 在 LLM
/// 流式输出期间写入，由 `MessageListView` 读取并拼接到列表末尾渲染。
///
/// 定位为底层能力服务:在所有消息相关插件(MessageStore 62 / MessageSender 63 /
/// AgentTurnRunner 64)之前注册，确保 runner 写入、UI 读取时该服务已就绪。
@MainActor
public final class MessageStreamingPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-streaming")
    public nonisolated static let emoji = "🌊"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.message-streaming"
    public let name = "Message Streaming"
    public let order = 61  // Before MessageManagerPlugin (62) and AgentTurnRunner (64)
    public let policy: LumiPluginPolicy = .alwaysOn

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)MessageStreamingPlugin")
        }
    }

    // MARK: - LumiPlugin

    public func onBoot(kernel: LumiKernel) async throws {
        let store = MessageStreamingStore(kernel: kernel)
        try kernel.registerMessageStreaming(store)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 MessageStreamingStore")
            Self.logger.info("\(Self.t)MessageStreamingPlugin boot 完成")
        }
    }

    public func onReady(kernel: LumiKernel) async throws {}


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
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
