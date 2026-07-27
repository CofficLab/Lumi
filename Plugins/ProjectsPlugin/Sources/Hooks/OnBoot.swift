import Foundation
import LumiKernel
import SuperLogKit
import os

/// Projects 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的所有初始化逻辑：
/// - 注册 ProjectService（内核服务）
@MainActor
public struct ProjectsOnBootHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects")
    nonisolated static let verbose = false
    nonisolated public static let emoji = "📂"

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        // 1. 注册 ProjectService（内核服务）— 必须在 onReady 之前完成
        let store: ProjectsStore?
        if let storage = kernel.storage {
            store = ProjectsStore(pluginDirectory: storage.pluginDataDirectory(for: "Projects"))
        } else {
            store = nil
        }
        let projectService = ProjectService(store: store)
        kernel.registerProject(projectService)

        if Self.verbose {
            Self.logger.info("📂 Registered ProjectService")
        }

        // 2. 启动时同步当前项目状态
        guard let project = kernel.project else {
            Self.logger.error("\(Self.t)ProjectService 注册后仍为 nil")
            return
        }
        let viewModel = ProjectsToolRuntimeBridge.viewModel
        if let currentProject = viewModel?.currentProject {
            try await project.openProject(at: currentProject.path)
        }

        if Self.verbose {
            Self.logger.info("📂 Projects 插件 boot 完成")
        }
    }
}
