import KernelLumi
import SuperLogKit
import LumiUI
import os
import SwiftUI

/// Disk Manager 插件
///
/// 向 KernelLumi 注册磁盘管理功能：
/// - ViewContainer：侧边栏磁盘管理视图
@MainActor
public final class DiskManagerPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.disk-manager")
    public nonisolated static let emoji = "💿"
    nonisolated static var verbose: Bool { false }

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.disk-manager"

    /// 本插件 rail 面板的稳定标识（注册为 `PanelRailTabItem.id`）。
    public nonisolated static let railTabID = "com.coffic.lumi.plugin.disk-manager.categories"

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

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {}

    // MARK: - Agent Tools

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
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

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
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

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: name,
                placement: .center,
                order: 0
            ) {
                DiskManagerToolbarTitleView(containerID: self.id, kernel: kernel, title: self.name)
            },
        ]
    }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: Self.railTabID,
                title: PluginDiskManagerLocalization.string("Cleanup"),
                systemImage: "list.bullet.indent",
                visibility: .viewContainer(id: id)
            ) {
                DiskCleanupCategorySidebar(store: self.categoryStore)
            }
        ]
    }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(DiskManagerAboutView())
    }
    public func pluginManualView(kernel: KernelLumi) -> AnyView? {
        AnyView(DiskManagerManualView())
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
