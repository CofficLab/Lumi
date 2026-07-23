import Foundation
import SwiftUI
import LumiKernel
import SuperLogKit
import os

/// 布局插件
///
/// 向 LumiKernel 注册 Layout 服务。
@MainActor
public final class LayoutKernelPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout")
    nonisolated public static let emoji = "📐"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.layout"
    public let name = "Layout Plugin"
    public let order = 40
	public let policy: LumiPluginPolicy = .disabled  // 核心插件

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onBoot(kernel: LumiKernel) throws {}

    public func onReady(kernel: LumiKernel) async throws {
        let layoutService = LayoutService()
        kernel.registerLayout(layoutService)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Layout 服务")
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func sendMiddlewares(kernel: LumiKernel) -> [any LumiSendMiddleware] { [] }
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