import Foundation
import LumiKernel
import SuperLogKit
import os

/// MenuBar 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct MenuBarOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        // 1. 注册 MenuBarService（内核服务）
        let menuBarServiceInstance = DefaultMenuBarProviding()
        kernel.registerMenuBarService(menuBarServiceInstance)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 MenuBar 插件到内核")
            Self.logger.info("\(Self.t)MenuBar 插件启动完成")
        }
    }
}
