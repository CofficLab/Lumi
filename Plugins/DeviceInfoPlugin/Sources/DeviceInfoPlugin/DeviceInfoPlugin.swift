import Foundation
import KernelLumi
import os
import SuperLogKit
import SwiftUI

/// 设备信息内核插件
///
/// 向 KernelLumi 注册设备信息相关的视图容器。
@MainActor
public final class DeviceInfoPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.device-info")
    public nonisolated static let emoji = "📊"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.device-info"
    public var name: String {
        LumiPluginLocalization.string("Device Info Plugin", bundle: .module)
    }
    public let order = 6
    public let policy: LumiPluginPolicy = .optIn // 功能插件
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        // Configure storage directory for MemoryHistoryService
        if let storage = kernel.storage {
            let pluginStorageDir = storage.pluginDataDirectory(for: id)
            MemoryHistoryService.configure(storageDirectory: pluginStorageDir)
        }
    }

    public func onReady(kernel: KernelLumi) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)已准备 DeviceInfo 菜单栏贡献")
        }
    }

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: LumiPluginLocalization.string("Device Info", bundle: .module),
                systemImage: "macbook.and.iphone",
                supportsProject: false,
                railVisibility: .unsupported,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                DeviceInfoView()
            },
        ]
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] {
        [
            MenuBarContentItem(id: "\(id).metrics", order: order) {
                DeviceInfoMenuBarContentView()
            }
        ]
    }

    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] {
        [
            MenuBarPopupItem(id: "\(id).cpu", order: order) {
                DeviceInfoMenuBarPopupView()
            },
            MenuBarPopupItem(id: "\(id).memory", order: order) {
                MemoryMenuBarPopupView()
            }
        ]
    }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
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
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(DeviceInfoAboutView())
    }
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
