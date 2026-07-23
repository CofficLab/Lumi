import Foundation
import LumiKernel
import SuperLogKit
import os

/// TitleToolbar 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct TitleToolbarOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.title-toolbar")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        let titleToolbarServiceInstance = DefaultTitleToolbarProviding()
        kernel.registerTitleToolbarService(titleToolbarServiceInstance)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 TitleToolbar 插件到内核")
            Self.logger.info("\(Self.t)TitleToolbar 插件启动完成")
        }
    }
}
