import Foundation
import LumiKernel
import SuperLogKit
import os

/// AgentTurnRunner 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的 AgentTurnManager 服务注册,确保在 onReady 之前内核已持有 AgentTurnManaging。
@MainActor
public struct AgentTurnRunnerOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-turn-runner")
    nonisolated static let verbose = true

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        let service = AgentTurnRunner(kernel: kernel)
        kernel.registerAgentTurnManagerService(service)
        if Self.verbose {
            Self.logger.info("已注册 AgentTurnRunner")
            Self.logger.info("AgentTurnRunnerPlugin boot 完成")
        }
    }
}
