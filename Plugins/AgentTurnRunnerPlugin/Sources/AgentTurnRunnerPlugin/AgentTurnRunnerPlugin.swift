import Foundation
import LumiKernel
import os
import SuperLogKit

/// Agent Turn Runner Plugin
///
/// Registers an `AgentTurnRunning` implementation with the kernel.
/// The implementation lives in `Services/AgentTurnRunnerService.swift`
/// and executes the full agent loop: LLM call → tool execution → repeat.
@MainActor
public final class AgentTurnRunnerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-turn-runner")
    public nonisolated static let emoji = "🤖"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.agent-turn-runner"
    public let name = "Agent Turn Runner"
    public let order = 64  // After MessageSendManagerPlugin (63)
    public static let policy: LumiPluginPolicy = .alwaysOn

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)AgentTurnRunnerPlugin")
        }
    }

    // MARK: - LumiPlugin

    public func onReady(kernel: LumiKernel) throws {
        let service = AgentTurnRunner(kernel: kernel)
        kernel.registerAgentTurnRunnerService(service)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 AgentTurnRunner")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)AgentTurnRunnerPlugin boot 完成")
        }
    }
}
