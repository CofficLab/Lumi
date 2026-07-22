import Foundation
import LumiKernel
import SuperLogKit
import os

/// 工具管理插件
///
/// 向 LumiKernel 注册 ToolManager 服务,并注册 5 个核心工具:
/// ListDirectoryTool, ReadFileTool, WriteFileTool, EditFileTool, ShellTool.
@MainActor
public final class ToolManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-manager")
    nonisolated public static let emoji = "🔧"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.tool-manager"
    public let name = "ToolManager Plugin"
    public let order = 30
    public static let policy: LumiPluginPolicy = .alwaysOn

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
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

        let tools = toolManagerService.allAgentTools()
        Self.logger.info("\(Self.t)已注册 \(tools.count) 个核心工具")
    }

    public func boot(kernel: LumiKernel) async throws {
        // No additional boot logic needed
    }
}
