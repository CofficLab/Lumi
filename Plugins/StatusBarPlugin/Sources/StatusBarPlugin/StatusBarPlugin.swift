import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 状态栏插件
///
/// 提供 StatusBarProviding 服务的默认实现。
/// 负责管理所有插件的状态栏项的注册和查询。
@MainActor
public final class StatusBarPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.statusbar")
    nonisolated public static let emoji = "🔔"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.statusbar"
    public let name = "StatusBar Plugin"
    public let order = 19  // 核心插件，优先注册

    // MARK: - State

    private var statusBarService: DefaultStatusBarProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 StatusBarService（内核服务）
        let statusBarServiceInstance = DefaultStatusBarProviding()
        kernel.registerStatusBarService(statusBarServiceInstance)
        self.statusBarService = statusBarServiceInstance

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 StatusBar 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)StatusBar 插件启动完成")
        }
    }
}
