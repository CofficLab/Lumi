import Foundation
import LumiKernel
import SuperLogKit
import os

/// Panel 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct PanelOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.panel")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        // 1. 注册 PanelService（内核服务）
        let panelServiceInstance = DefaultPanelProviding()
        kernel.registerPanelService(panelServiceInstance)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Panel 插件到内核")
            Self.logger.info("\(Self.t)Panel 插件启动完成")
        }
    }
}
