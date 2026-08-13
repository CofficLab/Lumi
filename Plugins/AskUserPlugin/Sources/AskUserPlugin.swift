import AgentToolKit
import Foundation
import KernelLumi
import os
import SuperLogKit
import SwiftUI

/// 用户询问插件
///
/// 提供 ask_user 工具，让 LLM 可以向用户提问并等待回答。
/// 支持是/否选择、多选项选择和自由文本输入。
///
/// ## 架构
///
/// - `AskUserTool`: LumiAgentTool，实现工具逻辑，检测多选关键词，构建 pending 响应
/// - `AskUserRowRenderer`: ToolCallRowRenderer，在 awaitingUserResponse 状态下渲染自定义 UI
/// - `AskUserBridge`: 单例，用户点击后直接调用内核 AgentTurnManager 恢复 Turn
@MainActor
public final class AskUserPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "❓"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.ask-user")

    // MARK: - LumiPlugin Identity

    public let id = "plugin-ask-user"
    public var name: String {
        LumiPluginLocalization.string("AskUser", bundle: .module)
    }
    public let order = 100
    public let policy: LumiPluginPolicy = .alwaysOn
    public let category: LumiPluginCategory = .general
    public let stage: LumiPluginStage = .beta
    public let pluginDescription = "Provides ask_user tool, letting LLM ask the user questions and wait for responses."

    public init() {}

    // MARK: - Lifecycle

    public func onBoot(kernel: KernelLumi) async throws {
        AskUserBridge.shared.start(kernel: kernel)

        if Self.verbose {
            Self.logger.info("\(Self.t)AskUserPlugin onBoot")
        }
    }

    public func onReady(kernel: KernelLumi) async throws {
        // 注册 ToolCallRowRenderer
        ToolCallRowRendererRegistry.shared.register(AskUserRowRenderer())

        if Self.verbose {
            Self.logger.info("\(Self.t)AskUserPlugin onReady")
        }
    }

    // MARK: - Agent Tools

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [AskUserTool()]
    }

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
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
