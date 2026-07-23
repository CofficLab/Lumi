import Foundation
import LumiKernel
import SuperLogKit
import os

/// Command 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的 Command 服务注册,确保在 onReady 之前内核已持有 CommandProviding。
@MainActor
public struct CommandOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.command")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        // 1. 注册 CommandService（内核服务）
        let commandServiceInstance = DefaultCommandProviding()
        kernel.registerCommandService(commandServiceInstance)

        if Self.verbose {
            Self.logger.info("已注册 Command 插件到内核")
            Self.logger.info("Command 插件启动完成")
        }
    }
}
