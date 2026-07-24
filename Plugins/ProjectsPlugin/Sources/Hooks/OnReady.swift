import Foundation
import LumiKernel
import SwiftUI
import SuperLogKit
import os

/// Projects 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑：
/// - ProjectsStore / ProjectsViewModel / ProjectsSyncCoordinator 初始化
/// - Agent Tools
/// - 设置 RuntimeBridge 供 titleToolbarItems 声明式访问与工具使用
///
/// 标题栏工具栏项由 `LumiPlugin.titleToolbarItems(kernel:)` 声明式提供，
/// 由 BuiltinPluginManager 在 registerPluginUIContributions 阶段收集。
/// ProjectService 的注册已在 OnBoot 阶段完成。
@MainActor
public struct ProjectsOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects")
    nonisolated static let verbose = false

    public let pluginID: String

    public init(pluginID: String) {
        self.pluginID = pluginID
    }

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        // 1. 初始化存储
        guard let storage = kernel.storage else {
            Self.logger.error("📂 Storage service not available，跳过 Projects 插件初始化")
            return
        }
        let storageDirectory = storage.pluginDataDirectory(for: "Projects")
        let store = ProjectsStore(pluginDirectory: storageDirectory)

        if Self.verbose {
            Self.logger.info("📂 Initialized ProjectsStore")
        }

        // 迁移 v4 历史项目(必须在 ViewModel 初始化之前完成 —— ViewModel init 时会
        // loadProjects,此时 projects.json 应已含合并后的数据)。幂等 + 吞错。
        ProjectsLegacyMigration(currentDataRootDirectory: storage.dataRootDirectory, store: store).run()

        // 2. 初始化 ViewModel
        let viewModel = ProjectsViewModel(store: store)

        if Self.verbose {
            Self.logger.info("📂 Initialized ProjectsViewModel")
        }

        // 3. 初始化同步协调器
        let coordinator = ProjectsSyncCoordinator(viewModel: viewModel)
        coordinator.kernel = kernel

        if Self.verbose {
            Self.logger.info("📂 Initialized ProjectsSyncCoordinator")
        }

        // 4. 设置 RuntimeBridge — 供 Agent 工具使用，并供
        //    `titleToolbarItems(kernel:)` 声明式访问 viewModel（在 onReady 之后
        //    由 BuiltinPluginManager.registerPluginUIContributions 收集）。
        ProjectsToolRuntimeBridge.viewModel = viewModel

        // 5. 注册 Agent Tools
        guard let toolManager = kernel.toolManager else {
            throw ProjectsPluginError.toolManagerNotAvailable
        }
        toolManager.add(ListProjectsTool(), pluginID: pluginID)
        toolManager.add(AddProjectTool(), pluginID: pluginID)
        toolManager.add(GetCurrentProjectTool(), pluginID: pluginID)

        if Self.verbose {
            Self.logger.info("📂 Registered Agent Tools: list_projects, add_project, get_current_project")
        }

        if Self.verbose {
            Self.logger.info("📂 Projects 插件 onReady 完成")
        }
    }
}
