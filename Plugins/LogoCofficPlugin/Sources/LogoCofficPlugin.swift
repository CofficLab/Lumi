import SwiftUI
import KernelLumi
import LumiUI
import os
import ProviderStorage
import SuperLogKit

@MainActor
public final class LogoCofficPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.logo-coffic")
    nonisolated public static let emoji = "☕️"
    nonisolated static let verbose = false

    public let id = "com.lumi.plugin.logo-coffic"
    public var name: String {
        LumiPluginLocalization.string("Coffic Logo", bundle: .module)
    }
    public let order = 100
	public let policy: LumiPluginPolicy = .alwaysOn

    public let category: LumiPluginCategory = .general
    public let stage: LumiPluginStage = .beta
    public let pluginDescription: String = "咖啡主题 Logo，提供动画咖啡杯图标"

    /// 插件数据目录（通过 ProviderStorage 提供）。
    private var pluginDataDirectory: URL?

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        // 参考 ProviderStorage：从内核存储服务获取插件专属数据目录。
        if let storage = kernel.storage {
            pluginDataDirectory = storage.pluginDataDirectory(for: id)
            if Self.verbose {
                Self.logger.info("\(Self.t)插件数据目录: \(self.pluginDataDirectory?.path ?? "nil")")
            }
        }
        Self.logger.info("\(Self.t)Coffic Logo 插件 onBoot 完成")
    }

    public func onReady(kernel: KernelLumi) async throws {
        // Logo items are registered in logoItems method
        Self.logger.info("\(Self.t)Coffic Logo 插件 onReady 完成")
    }


    public func logoItems(kernel: KernelLumi) -> [LogoItem] {
        [
            LogoItem(
                id: id,
                order: order,
                makeView: { scene in
                    CofficLogoView(scene: scene)
                }
            )
        ]
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
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
