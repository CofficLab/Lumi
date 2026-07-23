import Foundation
import LumiKernel
import SuperLogKit
import os

/// SendMiddleware 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct SendMiddlewareOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.send-middleware")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        // 1. 注册 SendMiddlewareService（内核服务）
        let sendMiddlewareServiceInstance = DefaultSendMiddlewareProviding()
        kernel.registerSendMiddlewareService(sendMiddlewareServiceInstance)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 SendMiddleware 插件到内核")
            Self.logger.info("\(Self.t)SendMiddleware 插件启动完成")
        }
    }
}
