import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// Logo 插件
///
/// 提供 LogoProviding 服务的默认实现。
/// 负责管理所有插件的 Logo 项的注册和查询。
@MainActor
public final class LogoPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.logo")
    nonisolated public static let emoji = "🖼️"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.logo"
    public let name = "Logo Plugin"
    public let order = 21  // 核心插件，优先注册

    // MARK: - State

    private var logoService: DefaultLogoProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 LogoService（内核服务）
        let logoServiceInstance = DefaultLogoProviding()
        kernel.registerLogoService(logoServiceInstance)
        self.logoService = logoServiceInstance

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Logo 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)Logo 插件启动完成")
        }
    }
}
