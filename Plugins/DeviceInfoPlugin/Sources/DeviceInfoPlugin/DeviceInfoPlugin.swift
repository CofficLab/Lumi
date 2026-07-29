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
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.device-info"
    public let name = "Device Info Plugin"
    public let order = 200
    public let policy: LumiPluginPolicy = .alwaysOn // 功能插件

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        // Configure storage directory for MemoryHistoryService
        if let storage = kernel.storage {
            let pluginStorageDir = storage.pluginDataDirectory(for: id)
            MemoryHistoryService.configure(storageDirectory: pluginStorageDir)
        }
    }

    public func onReady(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)已准备 DeviceInfo 菜单栏贡献")
        }
    }

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: "Device Info",
                systemImage: "macbook.and.iphone",
                isRailVisible: false,
                isChatVisible: false,
                isContentVisible: true,
                isPanelVisible: true,
                isPanelHeaderVisible: false,
                isPanelBottomVisible: false
            ) {
                DeviceInfoView()
            },
        ]
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] {
        [
            MenuBarContentItem(id: "\(id).metrics", order: order) {
                DeviceInfoMenuBarContentView()
            }
        ]
    }

    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] {
        [
            MenuBarPopupItem(id: "\(id).cpu", order: order) {
                DeviceInfoMenuBarPopupView()
            },
            MenuBarPopupItem(id: "\(id).memory", order: order) {
                MemoryMenuBarPopupView()
            }
        ]
    }
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
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
        [
            SettingsTabItem(
                id: id,
                title: LumiPluginLocalization.string("Device Info", bundle: .module),
                systemImage: "memorychip",
                order: order
            ) {
                MemorySettingsView()
            },
        ]
    }
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
