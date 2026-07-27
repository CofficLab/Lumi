import Foundation
import LumiKernel
import SuperLogKit
import os

/// EditorKernel 插件 OnReady 阶段钩子
///
/// EditorService 实例已在 OnBoot 阶段注册完毕。此钩子保留为空,以便未来扩展
/// 需要在所有服务就绪后执行的异步初始化逻辑(例如 LSP 服务预热、主题订阅等)。
@MainActor
public struct EditorKernelOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-kernel")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        if Self.verbose {
            Self.logger.info("EditorKernel onReady (no-op, 服务已在 OnBoot 注册)")
        }
    }
}
