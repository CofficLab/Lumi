import Foundation
import SwiftUI
import KernelLumi
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
    public var name: String {
        LumiPluginLocalization.string("Message Streaming", bundle: .module)
    }
    public let order = 61  // Before MessageManagerPlugin (62) and AgentTurnRunner (64)
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)MessageStreamingPlugin")
        }
    }

    // MARK: - LumiPlugin

    public func onBoot(kernel: KernelLumi) async throws {
        let store = MessageStreamingStore(kernel: kernel)
        try kernel.registerMessageStreaming(store)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 MessageStreamingStore")
            Self.logger.info("\(Self.t)MessageStreamingPlugin boot 完成")
        }
    }

    public func onReady(kernel: KernelLumi) async throws {}


    // MARK: - LumiPlugin stubs

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
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
