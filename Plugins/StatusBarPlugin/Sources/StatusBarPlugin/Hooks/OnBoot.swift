import Foundation
import LumiKernel
import SuperLogKit
import os

/// StatusBar 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的 StatusBar 服务注册,确保在 onReady 之前内核已持有 StatusBarProviding。
@MainActor
public struct StatusBarOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.statusbar")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        // 1. 注册 StatusBarService（内核服务）
        let statusBarServiceInstance = DefaultStatusBarProviding()
        kernel.registerStatusBarService(statusBarServiceInstance)

        if Self.verbose {
            Self.logger.info("已注册 StatusBar 插件到内核")
            Self.logger.info("StatusBar 插件启动完成")
        }
    }
}
