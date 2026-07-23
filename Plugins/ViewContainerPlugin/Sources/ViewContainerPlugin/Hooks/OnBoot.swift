import Foundation
import LumiKernel
import SuperLogKit
import os

/// ViewContainer 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的 ViewContainer 服务注册,确保在 onReady 之前内核已持有 ViewContainerProviding。
@MainActor
public struct ViewContainerOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.viewcontainer")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        let viewContainerServiceInstance = DefaultViewContainerProviding()
        kernel.registerViewContainerService(viewContainerServiceInstance)

        if Self.verbose {
            Self.logger.info("已注册 ViewContainer 插件到内核")
            Self.logger.info("ViewContainer 插件启动完成")
        }
    }
}
