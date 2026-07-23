import Foundation
import LumiKernel
import SuperLogKit
import os

/// MenuBar 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的 MenuBar 服务注册,确保在 onReady 之前内核已持有 MenuBarProviding。
@MainActor
public struct MenuBarOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        // 1. 注册 MenuBarService（内核服务）
        let menuBarServiceInstance = DefaultMenuBarProviding()
        kernel.registerMenuBarService(menuBarServiceInstance)

        if Self.verbose {
            Self.logger.info("已注册 MenuBar 插件到内核")
            Self.logger.info("MenuBar 插件启动完成")
        }
    }
}
