import Foundation
import LumiKernel
import SuperLogKit
import os

/// Projects 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的所有初始化逻辑
@MainActor
public struct ProjectsOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        let viewModel = ProjectsToolRuntimeBridge.viewModel

        // 启动时同步当前项目状态
        if let currentProject = viewModel?.currentProject {
            try? await kernel.project?.openProject(at: currentProject.path)
        }

        if Self.verbose {
            Self.logger.info("📂 Projects 插件 boot 完成")
        }
    }
}
