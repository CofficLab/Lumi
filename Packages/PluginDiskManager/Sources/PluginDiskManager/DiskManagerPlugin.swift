import AgentToolKit
import KernelCore
import os
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderToolManager
import SwiftUI

/// Disk Manager 插件（KernelCore 版本）
///
/// 由旧版 `Plugins/DiskManagerPlugin`（KernelLumi / LumiPlugin 架构）复刻而来，
/// 参考 `PluginDevice` / `PluginResumeDesigner` 的装配方式：
/// - `onBoot` 注册 Agent 工具、Rail 标签（清理类型侧边栏）、ActivityBar 入口
///   （主内容 `DiskManagerView`）与 Docs 文档（关于 / 说明书）；
/// - `onShutdown` 全部撤回。
///
/// 与旧版的对应关系：
/// - `agentTools` → `ToolManagerProviding`（10 个工具，`LumiAgentTool` → `SuperAgentTool`）；
/// - `viewContainers` → `ContentViewProviding.setContentView` + `ActivityBarProviding`；
/// - `panelRailTabItems` → `RailViewProviding.addTabs`（`DiskCleanupCategorySidebar`）；
/// - `pluginAboutView` / `pluginManualView` → `DocsViewProviding.addAbout` / `addManual`；
/// - `titleToolbarItems`（居中标题）：新版 `center` placement 已被 `ProjectsPlugin`
///   占用且无「容器激活」语义，故不复刻（与 PluginDevice / PluginResumeDesigner 一致）。
@MainActor
public final class DiskManagerPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.disk-manager"
    public let order = 250
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.disk-manager",
        name: "Disk Manager",
        description: "",
        category: .system,
        stage: .stable,
        policy: .disabledByDefault
    )

    /// 本插件 rail 面板的稳定标识（注册为 `RailTabItem.id`）。
    public static let railTabID = "com.coffic.lumi.plugin.disk-manager.categories"

    public var name: String {
        PluginDiskManagerLocalization.string("Disk Manager")
    }


    // MARK: - Logging（兼容旧版 ViewModel 的 DiskManagerPlugin.verbose / logger 引用）

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.disk-manager")
    public nonisolated static var verbose: Bool { false }

    /// 磁盘清理类型选中状态：sidebar rail 与 main view 共享同一份，
    /// 避免在 rail 切换后 main view 仍停留在旧类型上。
    private let categoryStore = DiskCleanupCategoryStore()

    /// 5 个清理类型的共享 ViewModel 容器：让多个清理类型可以同时工作
    /// （扫描结果不因切换类型而丢失）。
    private let workspace = DiskCleanupWorkspace()

    public init() {}

    // MARK: - SuperPlugin

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 注册 Agent 工具到 ToolManagerProviding。
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }

        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)

        // 2. 注册 Rail 标签。
        //    必须先注册 Rail，再注册 ActivityBar，确保首次激活回调能找到贡献。
        railView?.addTabs([
            RailTabItem(
                id: Self.railTabID,
                groupID: id,
                title: PluginDiskManagerLocalization.string("Cleanup"),
                systemImage: "list.bullet.indent",
                order: order
            ) {
                DiskCleanupCategorySidebar(store: self.categoryStore)
            },
        ])

        // 3. 注册 ActivityBar 入口；入口被激活时由插件切换自己的主内容。
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: name,
                    systemImage: "internaldrive",
                    order: order,
                    ownerPluginID: id
                ) { activeItemID in
                    guard activeItemID == entryID else { return }
                    contentView?.setContentView(AnyView(
                        DiskManagerView(categoryStore: self.categoryStore, workspace: self.workspace)
                    ))
                    railView?.activateGroup(id: self.id)
                },
            ])
        } else {
            // 无 ActivityBar 的精简宿主仍可直接展示插件主内容。
            contentView?.setContentView(AnyView(
                DiskManagerView(categoryStore: self.categoryStore, workspace: self.workspace)
            ))
        }

        // 4. 贡献「关于」与「说明书」文档（沿用旧版 pluginAboutView / pluginManualView）。
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { DiskManagerAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { DiskManagerManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 撤回注册的 Agent 工具。
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }

        kernel.resolveProvider((any RailViewProviding).self)?
            .removeTabs(ids: [Self.railTabID])

        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        activityBar?.removeItems(ids: ["\(id).entry"])
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }

        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    // MARK: - Agent Tools

    /// 本插件贡献的 Agent 工具（复刻旧版 DiskManagerPlugin.agentTools）。
    public static let agentTools: [any SuperAgentTool] = [
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
