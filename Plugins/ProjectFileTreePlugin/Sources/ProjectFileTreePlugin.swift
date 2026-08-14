import KernelLumi
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// 项目文件树插件
///
/// 在 RailView 中贡献 "Explorer" 标签,托管基于 NSCollectionView 的文件树
/// (TreeView)。提供文件浏览、Git 状态徽标、拖放、增删改、多选等完整能力。
@MainActor
public final class ProjectFileTreePlugin: LumiPlugin, SuperLog {
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project-file-tree")
    public nonisolated static let emoji = "🌲"
    public nonisolated static let verbose = false

    // MARK: - 功能开关

    /// 是否启用 Git 状态徽标(基于 libgit2)。
    public nonisolated static let gitStatusEnabled = true
    /// 是否启用拖放(文件移动)。
    public nonisolated static let dragAndDropEnabled = true
    public let id = "com.coffic.lumi.plugin.project-file-tree"

    /// 本插件 rail 面板的稳定标识（注册为 `PanelRailTabItem.id`）。
    public nonisolated static let railTabID = "explorer"

    public var name: String {
        LumiPluginLocalization.string("Project File Tree", bundle: .module)
    }
    public let order = 0
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        // 通过 Storage service 解析插件目录,供 FileTreeSettings 持久化展开状态。
        if let pluginDirectory = kernel.storage?.pluginDataDirectory(
            for: ProjectFileTreePluginRuntimeBridge.pluginName
        ) {
            FileTreeSettings.shared.configure(pluginDirectory: pluginDirectory)
        }
    }

    public func onReady(kernel: KernelLumi) async throws {}

    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: Self.railTabID,
                title: "Explorer",
                systemImage: "square.grid.2x2.fill",
                requiresProjectSupport: true
            ) {
                TreeView(kernel: kernel)
            }
        ]
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
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
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
