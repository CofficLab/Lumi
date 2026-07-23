import Foundation
import LumiKernel
import SuperLogKit
import os

/// MenuBar 插件 OnReady 阶段钩子
///
/// MenuBar 服务的注册已在 OnBoot 阶段完成。此钩子保留为空,以便未来扩展
/// 需要在所有服务就绪后执行的异步初始化逻辑。
@MainActor
public struct MenuBarOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        if Self.verbose {
            Self.logger.info("MenuBar onReady (no-op, 服务已在 OnBoot 注册)")
        }
    }
}
