import Foundation
import LumiKernel
import SwiftUI
import SuperLogKit
import os

/// Projects 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑：
/// - ProjectService
/// - TitleToolbarItem
/// - Agent Tools
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
        // 1. 注册 ProjectService（内核服务）
        let projectService = ProjectService()
        kernel.registerProject(projectService)

        if Self.verbose {
            Self.logger.info("📂 Registered ProjectService")
        }

        // 2. 初始化存储
        guard let storage = kernel.storage else {
            registerErrorToolbar(kernel: kernel, message: "Storage service not available")
            return
        }
        let storageDirectory = storage.pluginDataDirectory(for: "Projects")
        let store = ProjectsStore(pluginDirectory: storageDirectory)

        if Self.verbose {
            Self.logger.info("📂 Initialized ProjectsStore")
        }

        // 3. 初始化 ViewModel
        let viewModel = ProjectsViewModel(store: store)

        if Self.verbose {
            Self.logger.info("📂 Initialized ProjectsViewModel")
        }

        // 4. 初始化同步协调器
        let coordinator = ProjectsSyncCoordinator(viewModel: viewModel)
        coordinator.kernel = kernel

        if Self.verbose {
            Self.logger.info("📂 Initialized ProjectsSyncCoordinator")
        }

        // 5. 注册标题栏工具栏项
        kernel.toolbarProvider?.registerTitleToolbarItem(
            TitleToolbarItem(
                id: "\(pluginID).toolbar",
                title: "Projects",
                placement: .center
            ) {
                ProjectControlView(viewModel: viewModel)
            }
        )

        if Self.verbose {
            Self.logger.info("📂 Registered TitleToolbarItem")
        }

        // 6. 注册 Agent Tools
        guard let toolManager = kernel.toolManager else {
            throw ProjectsPluginError.toolManagerNotAvailable
        }
        toolManager.add(ListProjectsTool())
        toolManager.add(AddProjectTool())
        toolManager.add(GetCurrentProjectTool())

        if Self.verbose {
            Self.logger.info("📂 Registered Agent Tools: list_projects, add_project, get_current_project")
        }

        // 7. 设置 RuntimeBridge 供工具使用（boot 阶段会读取）
        ProjectsToolRuntimeBridge.viewModel = viewModel

        if Self.verbose {
            Self.logger.info("📂 Projects 插件 onReady 完成")
        }
    }

    private func registerErrorToolbar(kernel: LumiKernel, message: String) {
        kernel.toolbarProvider?.registerTitleToolbarItem(
            TitleToolbarItem(
                id: "\(pluginID).toolbar",
                title: "Projects",
                placement: .center
            ) {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Projects Error")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .help(message)
            }
        )

        if Self.verbose {
            Self.logger.info("📂 Registered error TitleToolbarItem")
        }
    }
}
