import Foundation
import LumiKernel
import SuperLogKit
import os

/// LayoutKernel 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的核心 Layout 服务注册,确保在 onReady 之前内核已持有 LayoutProviding。
@MainActor
public struct LayoutKernelOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        let layoutService = LayoutService()
        kernel.registerLayout(layoutService)
        if Self.verbose {
            Self.logger.info("已注册 Layout 服务")
        }
    }
}
