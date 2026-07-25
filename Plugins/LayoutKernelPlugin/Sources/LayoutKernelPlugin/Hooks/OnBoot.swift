import Foundation
import LumiKernel
import os
import SuperLogKit

/// LayoutKernel 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的核心 Layout 服务注册,确保在 onReady 之前内核已持有 LayoutProviding。
///
/// 持久化由外层 Layout 插件自行负责，在初始化时从磁盘读取并写入 LayoutState。
@MainActor
public struct LayoutKernelOnBootHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout")
    nonisolated static let verbose = true

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        kernel.registerLayout(LayoutManager())

        if Self.verbose {
            Self.logger.info("\(Self.t)Layout service registered successfully")
        }
    }
}
