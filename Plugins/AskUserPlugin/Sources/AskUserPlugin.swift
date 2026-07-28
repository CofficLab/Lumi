import AgentToolKit
import Foundation
import LumiKernel
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
/// - `AskUserBridge`: 单例，用户点击后 post `.lumiAskUserDidAnswer` 通知
/// - `AskUserResumeObserver`: 在 onBoot 时启动，监听通知、覆盖 pending result、重启 turn
@MainActor
public final class AskUserPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "❓"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.ask-user")

    // MARK: - LumiPlugin Identity

    public let id = "plugin-ask-user"
    public let name = "AskUser"
    public let order = 100
    public let policy: LumiPluginPolicy = .alwaysOn
    public let category: LumiPluginCategory = .general
    public let stage: LumiPluginStage = .beta
    public let pluginDescription = "Provides ask_user tool, letting LLM ask the user questions and wait for responses."

    public init() {}

    // MARK: - Lifecycle

    public func onBoot(kernel: LumiKernel) async throws {
        // 启动 AskUserResumeObserver，监听用户回答通知
        AskUserResumeObserver.shared.start(kernel: kernel)

        if Self.verbose {
            Self.logger.info("\(Self.t)AskUserPlugin onBoot")
        }
    }

    public func onReady(kernel: LumiKernel) async throws {
        // 注册 ToolCallRowRenderer
        ToolCallRowRendererRegistry.shared.register(AskUserRowRenderer())

        if Self.verbose {
            Self.logger.info("\(Self.t)AskUserPlugin onReady")
        }
    }

    // MARK: - Agent Tools

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [AskUserTool()]
    }

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
