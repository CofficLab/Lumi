import Foundation
import LumiKernel
import SuperLogKit
import os

/// Logo 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的 Logo 服务注册,确保在 onReady 之前内核已持有 LogoProviding。
@MainActor
public struct LogoOnBootHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.logo")
    nonisolated static let verbose = true

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        // 1. 注册 LogoService（内核服务）
        let logoServiceInstance = LogoManager()
        kernel.registerLogoService(logoServiceInstance)

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Logo 管理插件到内核")
        }
    }
}
