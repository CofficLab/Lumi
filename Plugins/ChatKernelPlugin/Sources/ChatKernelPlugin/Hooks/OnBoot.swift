import Foundation
import LumiKernel
import SuperLogKit
import os

/// ChatKernel 插件 OnBoot 阶段钩子
///
/// Chat 服务未注册到内核(它是一个独立的子系统,不是必需的 Providing 服务)。
/// 此钩子保留以维持与其它核心插件一致的 OnBoot 模式,便于未来扩展。
@MainActor
public struct ChatKernelOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("ChatKernelPlugin OnBoot (Chat 服务无需内核注册)")
        }
    }
}
