import Foundation
import LumiKernel
import SuperLogKit
import os

/// TitleToolbar 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的 TitleToolbar 服务注册,确保在 onReady 之前内核已持有 TitleToolbarProviding。
@MainActor
public struct TitleToolbarOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.title-toolbar")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        let titleToolbarServiceInstance = DefaultTitleToolbarProviding()
        kernel.registerTitleToolbarService(titleToolbarServiceInstance)

        if Self.verbose {
            Self.logger.info("已注册 TitleToolbar 插件到内核")
            Self.logger.info("TitleToolbar 插件启动完成")
        }
    }
}
