import Foundation
import LumiKernel
import SuperLogKit
import os

/// ViewContainer 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct ViewContainerOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.viewcontainer")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        let viewContainerServiceInstance = DefaultViewContainerProviding()
        kernel.registerViewContainerService(viewContainerServiceInstance)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 ViewContainer 插件到内核")
            Self.logger.info("\(Self.t)ViewContainer 插件启动完成")
        }
    }
}
