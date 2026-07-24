import Foundation
import LumiKernel
import SuperLogKit
import os

/// LayoutKernel 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的核心 Layout 服务注册,确保在 onReady 之前内核已持有 LayoutProviding。
@MainActor
public struct LayoutKernelOnBootHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout")
    nonisolated static let verbose = true

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)registering Layout service...")
        }

        let layoutService = LayoutService()
        kernel.registerLayout(layoutService)

        if Self.verbose {
            Self.logger.info("\(Self.t)Layout service registered successfully")
        }
    }
}
