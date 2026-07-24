import Foundation
import LumiKernel
import os
import SuperLogKit
import SwiftUI

/// 设备信息内核插件
///
/// 向 LumiKernel 注册设备信息相关的视图容器。
@MainActor
public final class DeviceInfoPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.device-info")
    public nonisolated static let emoji = "📊"
    nonisolated static let verbose = true

    public let id = "com.coffic.lumi.plugin.device-info"
    public let name = "Device Info Plugin"
    public let order = 200
    public let policy: LumiPluginPolicy = .alwaysOn // 功能插件

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        guard policy.shouldRegister else { return }

        // 注册菜单栏内容（order 自动从插件继承）
        kernel.menuBar?.registerMenuBarContent(
            MenuBarContentItem(
                id: "\(id).metrics"
            ) {
                DeviceInfoMenuBarContentView()
            }
        )

        // 注册菜单栏弹出项（order 自动从插件继承）
        kernel.menuBar?.registerMenuBarPopup(
            MenuBarPopupItem(
                id: "\(id).cpu"
            ) {
                DeviceInfoMenuBarPopupView()
            }
        )

        kernel.menuBar?.registerMenuBarPopup(
            MenuBarPopupItem(
                id: "\(id).memory"
            ) {
                MemoryMenuBarPopupView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 DeviceInfo 视图容器到内核")
            Self.logger.info("\(Self.t)DeviceInfo 插件启动完成")
        }
    }

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: "Device Info",
                systemImage: "macbook.and.iphone"
            ) {
                DeviceInfoView()
            },
        ]
    }

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
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {
        if Self.verbose {
            Self.logger.info("\(Self.t)onContainerActivated,contaienrID: \(containerID)")
        }
        
        guard containerID == id else { return }
        if Self.verbose {
            Self.logger.info("\(Self.t)调整可见性")
        }
        
        guard let layoutManager = kernel.layoutManager else {
            Self.logger.warning("\(Self.t)No LayoutManager, ignore")
            return
        }
        
        layoutManager.layoutState.applyVisibility(
            rail: false,
            chat: false,
            content: true,
            activityBar: true,
            panel: true
        )
    }

    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
