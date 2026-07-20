import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// Projects 插件
///
/// 向 LumiKernel 注册项目管理相关的功能：
/// - ProjectService：项目状态管理服务
/// - TitleToolbarItem：标题栏项目控制视图
/// - AgentTools：list_projects, add_project, get_current_project
/// - SendMiddleware：ConversationHintMiddleware
@MainActor
public final class ProjectsPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects")
    nonisolated public static let emoji = "📂"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.projects"
    public let name = "Projects Plugin"
    public let order = 20  // 核心插件

    // MARK: - State

    private var projectService: ProjectService?
    private var store: ProjectsStore?
    private var viewModel: ProjectsViewModel?
    private var syncCoordinator: ProjectsSyncCoordinator?
    private var storageError: String?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 ProjectService（内核服务）
        let projectServiceInstance = ProjectService()
        kernel.registerProject(projectServiceInstance)
        self.projectService = projectServiceInstance

        // 2. 初始化存储（StoragePlugin order=10 先于本插件 order=20 加载）
        guard let storage = kernel.storage else {
            self.storageError = "Storage service not available"
            let errorView = Self.makeErrorView(message: self.storageError!)
            kernel.titleToolbar?.registerTitleToolbarItem(
                TitleToolbarItem(
                    id: "\(id).toolbar",
                    title: "Projects",
                    placement: .center
                ) {
                    errorView
                }
            )
            return
        }
        let storageDirectory = storage.pluginDataDirectory(for: "Projects")

        let storeInstance = ProjectsStore(pluginDirectory: storageDirectory)
        self.store = storeInstance

        // 3. 初始化 ViewModel
        let viewModelInstance = ProjectsViewModel(store: storeInstance)
        self.viewModel = viewModelInstance

        // 4. 初始化同步协调器
        let coordinator = ProjectsSyncCoordinator(viewModel: viewModelInstance)
        coordinator.kernel = kernel
        self.syncCoordinator = coordinator

        // 5. 注册标题栏工具栏项（order 自动从插件继承）
        kernel.titleToolbar?.registerTitleToolbarItem(
            TitleToolbarItem(
                id: "\(id).toolbar",
                title: "Projects",
                placement: .center
            ) {
                if let vm = self.viewModel {
                    ProjectControlView(viewModel: vm)
                } else {
                    Text("Projects")
                }
            }
        )

        // 6. 注册 Agent 工具
        kernel.agentTool?.add(ListProjectsTool())
        kernel.agentTool?.add(AddProjectTool())
        kernel.agentTool?.add(GetCurrentProjectTool())

        // 7. 注册发送中间件
        kernel.sendMiddleware?.registerSendMiddleware(ConversationHintMiddleware(), id: "\(id).middleware")

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Projects 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 设置 RuntimeBridge 供工具使用
        ProjectsToolRuntimeBridge.viewModel = viewModel

        // 启动时同步当前项目状态
        if let currentProject = viewModel?.currentProject {
            try? await kernel.project?.openProject(at: currentProject.path)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)Projects 插件启动完成")
        }
    }

    // MARK: - Error View

    private static func makeErrorView(message: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Projects Error")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .help(message)
    }
}