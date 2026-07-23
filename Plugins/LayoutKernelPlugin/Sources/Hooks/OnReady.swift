import Foundation
import LumiKernel
import SuperLogKit
import os

/// LayoutKernel 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct LayoutKernelOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        let layoutService = LayoutService()
        kernel.registerLayout(layoutService)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Layout 服务")
        }
    }
}
