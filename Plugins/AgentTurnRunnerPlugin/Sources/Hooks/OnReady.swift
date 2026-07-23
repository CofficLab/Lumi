import Foundation
import LumiKernel
import SuperLogKit
import os

/// AgentTurnRunner 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct AgentTurnRunnerOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-turn-runner")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        let service = AgentTurnRunner(kernel: kernel)
        kernel.registerAgentTurnRunnerService(service)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 AgentTurnRunner")
            Self.logger.info("\(Self.t)AgentTurnRunnerPlugin boot 完成")
        }
    }
}
