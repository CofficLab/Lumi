import KitAgentTool
import KernelCore
import os
import ProviderDocsView
import ProviderLogo
import ProviderMenuBar
import ProviderStorage
import ProviderToolManager
import KitSuperLog
import SwiftUI

/// Caffeinate 插件（KernelCore 版本）
///
/// 由旧版 `Plugins/CaffeinatePlugin`（KernelLumi / LumiPlugin 架构）复刻而来：
/// - `onBoot` 解析内核 `StorageProviding`（本地存储）与 `LogoProviding`（Logo 高亮），
///   配置 `CaffeinateManager`，注册 4 个 Agent 工具、菜单栏弹窗与「关于/说明书」文档；
/// - `onShutdown` 撤回全部贡献。
///
/// 与旧版的对应关系：
/// - `agentTools` → `ToolManagerProviding`（4 个工具）；
/// - `menuBarPopupItems` → `MenuBarProviding.addPopup`；
/// - `pluginAboutView` / `pluginManualView` → `DocsViewProviding.addAbout` / `addManual`；
/// - `kernel.storage` / `kernel.logo` → `StorageProviding` / `LogoProviding`。
///
/// 相比旧版移除：`viewContainers` 主界面（旧版已注释停用）。
@MainActor
public final class CaffeinatePlugin: SuperPlugin {
    public let id = "Caffeinate"
    public let order = 1
    public let metadata = PluginMetadata(
        id: "Caffeinate",
        name: "Caffeinate",
        description: "",
        category: .integration,
        stage: .stable,
        policy: .required
    )

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.caffeinate")
    public nonisolated static let verbose: Bool = false

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("Caffeinate", bundle: .module)
    }


    public func onBoot(kernel: KernelCoreContainer) throws {
        // 配置 Manager：存储目录 + Logo 高亮（沿用旧版 onReady 的 configure）。
        let storage = kernel.resolveProvider((any StorageProviding).self)
        let logo = kernel.resolveProvider((any LogoProviding).self)
        CaffeinateManager.shared.configure(storage: storage, logo: logo)

        // 注册 Agent 工具。
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }

        // 菜单栏弹窗（沿用旧版 menuBarPopupItems）。
        if let menuBar = kernel.resolveProvider((any MenuBarProviding).self) {
            menuBar.addPopup(MenuBarPopupItem(id: "\(id).popup", title: name, order: order) {
                CaffeinateMenuBarPopupView()
            })
        }

        // 「关于」与「说明书」文档（沿用旧版 pluginAboutView / pluginManualView）。
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { CaffeinateAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { CaffeinateManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }
        kernel.resolveProvider((any MenuBarProviding).self)?
            .removeItems(ids: ["\(id).popup"])
        kernel.resolveProvider((any DocsViewProviding).self)?
            .removeEntries(id: id)
    }

    // MARK: - Agent Tools

    public static let agentTools: [any SuperAgentTool] = [
        CaffeinateActivateTool(),
        CaffeinateDeactivateTool(),
        CaffeinateStatusTool(),
        CaffeinateTurnOffDisplayTool(),
    ]
}
