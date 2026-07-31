import Foundation
import SwiftUI
import LumiKernel
import os
import SuperLogKit

/// Message Timeline Plugin
///
/// 注册消息列表的**数据源** `MessageTimelineStore`(实现 `MessageTimelineProviding`)
/// 到内核,把消息列表的全部"消息知识"(行合并 / 分页策略 / 渲染器分发 /
/// 流式窄播订阅)收敛到数据层,让 `MessageListPlugin` 等 UI 插件只负责
/// 展示、滚动、分页触发等纯 UI 职责。
///
/// 定位为数据层服务:在 MessageStore(62)/ MessageStreaming(61)/
/// MessageSender(63)/ MessageRenderer 之后、MessageList UI(82)之前注册。
@MainActor
public final class MessageTimelinePlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-timeline")
    public nonisolated static let emoji = "📜"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.message-timeline"
    public let name = "Message Timeline"
    public let order = 81  // After message services (61–64), before MessageListPlugin (82)
    public let policy: LumiPluginPolicy = .alwaysOn

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)MessageTimelinePlugin")
        }
    }

    // MARK: - LumiPlugin

    public func onBoot(kernel: LumiKernel) async throws {
        let store = MessageTimelineStore(kernel: kernel)
        try kernel.registerMessageTimelineProvider(store)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 MessageTimelineStore")
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
