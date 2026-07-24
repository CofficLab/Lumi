import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 旧版本数据迁移插件(v4 → v5)
///
/// 在 onBoot 阶段定位 v4 旧数据目录,注册只读 `LegacyDataService`,供各 Store 插件
/// 在 onReady 阶段读取历史数据并迁移到各自的新库。
///
/// - 重要:本插件是「迁移窗口期」的临时代码。待用户基本都升级到 v5 后,应在后续版本
///   删除本插件及 `LegacyDataProviding` 协议。
@MainActor
public final class LegacyDataPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.legacy-data")
    nonisolated public static let emoji = "🗂️"
    nonisolated static let verbose = true

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.legacy-data"
    public let name = "Legacy Data Plugin"
    /// 紧随 Storage(10)之后,远早于消费插件(ConversationStore=61, MessageStore=62)。
    /// onBoot 全量先于 onReady 执行,故消费插件 onReady 时本服务一定已注册。
    public let order = 11
    public let policy: LumiPluginPolicy = .alwaysOn

    // MARK: - Lifecycle

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        try await LegacyDataOnBootHook().execute(kernel)
    }

    public func onReady(kernel: LumiKernel) async throws {
        // 迁移由各消费插件在各自 onReady 驱动,本插件 onReady 无需做事。
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
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
