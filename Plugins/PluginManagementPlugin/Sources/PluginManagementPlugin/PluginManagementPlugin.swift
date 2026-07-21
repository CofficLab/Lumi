import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// 插件管理插件
///
/// 提供 PluginProviding 服务的默认实现。
/// 同时充当 AgentToolProviding、ChatContributionProviding、UIThemeProviding 的实现。
/// 负责管理所有插件的注册、启动、查询和排序。
///
/// `LLMProviderProviding` 由独立的 `LLMProviderManagerPlugin` 提供。
@MainActor
public final class PluginManagementPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.plugin-management")
    public nonisolated static let emoji = "🔌"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.plugin-management"
    public let name = "PluginManagement Plugin"
    public let order = 5
    public static let policy: LumiPluginPolicy = .disabled  // 核心插件，最先注册

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 PluginService（内核服务）
        let pluginServiceInstance = PluginManagerProvider()
        pluginServiceInstance.kernel = kernel
        kernel.registerPluginService(pluginServiceInstance)
        // 2. 同一个实例还充当多个 Provider 服务的实现
        kernel.registerAgentToolService(pluginServiceInstance)
        kernel.registerChatContributionService(pluginServiceInstance)
        // 主题贡献由 UIThemeProviding 收集,通过 LumiKernel.plugin 访问
        // （不需要单独注册 ThemeProviding,因为 LumiKernel 自身从 plugin 读取）

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
