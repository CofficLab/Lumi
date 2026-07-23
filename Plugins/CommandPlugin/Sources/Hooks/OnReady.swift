import Foundation
import LumiKernel
import SuperLogKit
import os

/// Command 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct CommandOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.command")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        // 1. 注册 CommandService（内核服务）
        let commandServiceInstance = DefaultCommandProviding()
        kernel.registerCommandService(commandServiceInstance)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Command 插件到内核")
            Self.logger.info("\(Self.t)Command 插件启动完成")
        }
    }
}
