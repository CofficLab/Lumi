import LumiKernel
import SuperLogKit
import LumiUI
import os
import SwiftUI

/// Disk Manager 插件
///
/// 向 LumiKernel 注册磁盘管理功能：
/// - ViewContainer：侧边栏磁盘管理视图
@MainActor
public final class DiskManagerPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.disk-manager")
    public nonisolated static let emoji = "💿"
    nonisolated static var verbose: Bool { false }

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.disk-manager"
    public var name: String { PluginDiskManagerLocalization.string("Disk Manager") }
    public var pluginDescription: String { PluginDiskManagerLocalization.string("Disk space analysis and large file cleaning") }
    public let order = 250
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta

    /// 磁盘清理类型选中状态：sidebar rail 与 main view 共享同一份，
    /// 避免在 rail 切换后 main view 仍停留在旧类型上。
    private let categoryStore = DiskCleanupCategoryStore()

    /// 5 个清理类型的共享 ViewModel 容器：让多个清理类型可以同时工作
    /// （扫描结果不因切换类型而丢失）。
    private let workspace = DiskCleanupWorkspace()

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}

    // MARK: - Agent Tools

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            DiskUsageTool(),
            ScanLargeFilesTool(),
            ScanDirectoryTreeTool(),
            ScanCachesTool(),
            CleanCachesTool(),
            ScanXcodeCachesTool(),
            CleanXcodeCachesTool(),
            ScanProjectsTool(),
            CleanProjectsTool(),
            DeleteFilesTool(),
        ]
    }

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "internaldrive",
                railVisibility: .alwaysVisible,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                DiskManagerView(categoryStore: self.categoryStore, workspace: self.workspace)
            },
        ]
    }


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "\(id).categories",
                title: PluginDiskManagerLocalization.string("Cleanup"),
                systemImage: "list.bullet.indent",
                visibility: .viewContainer(id: id)
            ) {
                DiskCleanupCategorySidebar(store: self.categoryStore)
            }
        ]
    }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(DiskManagerAboutView())
    }
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
