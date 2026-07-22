import Foundation
import LumiKernel
import SuperLogKit
import os

/// Agent 工具插件
///
/// 向 LumiKernel 注册 ToolManager 服务。
@MainActor
public final class ToolManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-tool")
    nonisolated public static let emoji = "🔧"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.agent-tool"
    public let name = "ToolManager Plugin"
    public let order = 30
    public static let policy: LumiPluginPolicy = .alwaysOn

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        let agentToolService = ToolManagerService()
        kernel.registerToolManagerService(agentToolService)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 ToolManager 服务")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 无需额外启动逻辑
    }
}