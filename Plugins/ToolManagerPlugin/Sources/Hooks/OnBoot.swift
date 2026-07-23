import Foundation
import LumiKernel
import SuperLogKit
import os

/// ToolManager 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的所有初始化逻辑
@MainActor
public struct ToolManagerOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-manager")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        let toolManagerService = ToolManagerService()
        kernel.registerToolManagerService(toolManagerService)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 ToolManager 服务")
        }

        // Register 5 core tools
        toolManagerService.add(ListDirectoryTool())
        toolManagerService.add(ReadFileTool())
        toolManagerService.add(WriteFileTool())
        toolManagerService.add(EditFileTool())
        toolManagerService.add(ShellTool())
    }
}
