import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 设置插件
///
/// 提供 SettingsProviding 服务的默认实现。
/// 负责管理所有插件的设置标签项和 LLM 提供商设置项的注册和查询。
@MainActor
public final class SettingsPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.settings")
    nonisolated public static let emoji = "⚙️"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.settings"
    public let name = "Settings Plugin"
    public let order = 20  // 核心插件，优先注册

    // MARK: - State

    private var settingsService: DefaultSettingsProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 SettingsService（内核服务）
        let settingsServiceInstance = DefaultSettingsProviding()
        kernel.registerSettingsService(settingsServiceInstance)
        self.settingsService = settingsServiceInstance

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Settings 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)Settings 插件启动完成")
        }
    }
}
