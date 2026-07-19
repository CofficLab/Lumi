import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 插件管理插件
///
/// 提供 PluginProviding 服务的默认实现。
/// 负责管理所有插件的注册、启动、查询和排序。
@MainActor
public final class PluginManagementPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.plugin-management")
    nonisolated public static let emoji = "🔌"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.plugin-management"
    public let name = "PluginManagement Plugin"
    public let order = 5  // 核心插件，最先注册

    // MARK: - State

    private var pluginService: DefaultPluginProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 PluginService（内核服务）
        let pluginServiceInstance = DefaultPluginProviding()
        kernel.registerPluginService(pluginServiceInstance)
        self.pluginService = pluginServiceInstance

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 PluginManagement 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)PluginManagement 插件启动完成")
        }
    }
}
