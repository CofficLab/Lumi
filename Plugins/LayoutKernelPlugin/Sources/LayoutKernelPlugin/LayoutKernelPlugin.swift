import Foundation
import LumiKernel
import SuperLogKit
import os

/// 布局插件
///
/// 向 LumiKernel 注册 Layout 服务。
@MainActor
public final class LayoutKernelPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout")
    nonisolated public static let emoji = "📐"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.layout"
    public let name = "Layout Plugin"
    public let order = 40
public static let policy: LumiPluginPolicy = .disabled  // 核心插件

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        let layoutService = LayoutService()
        kernel.registerLayout(layoutService)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Layout 服务")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 无需额外启动逻辑
    }
}