import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 发送中间件插件
///
/// 提供 SendMiddlewareProviding 服务的默认实现。
/// 负责管理发送中间件的注册和执行。
@MainActor
public final class SendMiddlewarePlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.send-middleware")
    nonisolated public static let emoji = "📨"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.send-middleware"
    public let name = "SendMiddleware Plugin"
    public let order = 17
public static let policy: LumiPluginPolicy = .disabled  // 核心插件，优先注册

    // MARK: - State

    private var sendMiddlewareService: DefaultSendMiddlewareProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 SendMiddlewareService（内核服务）
        let sendMiddlewareServiceInstance = DefaultSendMiddlewareProviding()
        kernel.registerSendMiddlewareService(sendMiddlewareServiceInstance)
        self.sendMiddlewareService = sendMiddlewareServiceInstance

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 SendMiddleware 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)SendMiddleware 插件启动完成")
        }
    }
}
