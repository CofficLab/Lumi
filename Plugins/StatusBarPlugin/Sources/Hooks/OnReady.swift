import Foundation
import LumiKernel
import SuperLogKit
import os

/// StatusBar 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct StatusBarOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.statusbar")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        // 1. 注册 StatusBarService（内核服务）
        let statusBarServiceInstance = DefaultStatusBarProviding()
        kernel.registerStatusBarService(statusBarServiceInstance)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 StatusBar 插件到内核")
            Self.logger.info("\(Self.t)StatusBar 插件启动完成")
        }
    }
}
