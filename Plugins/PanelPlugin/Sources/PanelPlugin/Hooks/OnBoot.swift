import Foundation
import LumiKernel
import SuperLogKit
import os

/// Panel 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的 Panel 服务注册,确保在 onReady 之前内核已持有 PanelProviding。
@MainActor
public struct PanelOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.panel")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        // 1. 注册 PanelService（内核服务）
        let panelServiceInstance = DefaultPanelProviding()
        kernel.registerPanelService(panelServiceInstance)

        if Self.verbose {
            Self.logger.info("已注册 Panel 插件到内核")
            Self.logger.info("Panel 插件启动完成")
        }
    }
}
