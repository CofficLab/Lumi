import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 主题插件
///
/// 提供 ThemeProviding 服务的默认实现。
/// 负责管理所有插件的主题贡献的注册和查询。
@MainActor
public final class ThemePlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.theme")
    nonisolated public static let emoji = "🎨"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.theme"
    public let name = "Theme Plugin"
    public let order = 22  // 核心插件，优先注册

    // MARK: - State

    private var themeService: DefaultThemeProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 ThemeService（内核服务）
        let themeServiceInstance = DefaultThemeProviding()
        kernel.registerThemeService(themeServiceInstance)
        self.themeService = themeServiceInstance

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Theme 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)Theme 插件启动完成")
        }
    }
}
