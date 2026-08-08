import LumiKernel
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
    public var name: String {
        LumiPluginLocalization.string("Project File Tree", bundle: .module)
    }
    public let order = 0
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        // 通过 Storage service 解析插件目录,供 FileTreeSettings 持久化展开状态。
        if let pluginDirectory = kernel.storage?.pluginDataDirectory(
            for: ProjectFileTreePluginRuntimeBridge.pluginName
        ) {
            FileTreeSettings.shared.configure(pluginDirectory: pluginDirectory)
        }
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "explorer",
                title: "Explorer",
                systemImage: "square.grid.2x2.fill",
                requiresProjectSupport: true
            ) {
                TreeView(kernel: kernel)
            }
        ]
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
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
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
}
