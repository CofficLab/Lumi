import Foundation
import LumiKernel
import SuperLogKit
import os

/// Agent 工具插件
///
/// 向 LumiKernel 注册 AgentTool 服务。
@MainActor
public final class AgentToolPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-tool")
    nonisolated public static let emoji = "🔧"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.agent-tool"
    public let name = "AgentTool Plugin"
    public let order = 30  // 核心插件，在 Storage、Project 之后加载

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        let agentToolService = AgentToolService()
        kernel.registerAgentTool(agentToolService)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 AgentTool 服务")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 无需额外启动逻辑
    }
}