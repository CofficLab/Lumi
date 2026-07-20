import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 命令插件
///
/// 提供 CommandProviding 服务的默认实现。
/// 负责管理所有插件的命令菜单注册、分组和查询。
@MainActor
public final class CommandPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.command")
    nonisolated public static let emoji = "⌨️"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.command"
    public let name = "Command Plugin"
    public let order = 15
public static let policy: LumiPluginPolicy = .disabled  // 核心插件，优先注册

    // MARK: - State

    private var commandService: DefaultCommandProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 CommandService（内核服务）
        let commandServiceInstance = DefaultCommandProviding()
        kernel.registerCommandService(commandServiceInstance)
        self.commandService = commandServiceInstance

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Command 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)Command 插件启动完成")
        }
    }
}
