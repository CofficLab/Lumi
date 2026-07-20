import LumiKernel
import SuperLogKit
import LumiUI
import os
import SwiftUI

/// Brew Manager 插件
///
/// 向 LumiKernel 注册 Homebrew 包管理功能：
/// - ViewContainer：侧边栏包管理视图
@MainActor
public final class BrewManagerPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.brew-manager")
    public nonisolated static let emoji = "🍺"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.brew-manager"
    public let name = "Package Management"
    public let order = 60
public static let policy: LumiPluginPolicy = .disabled

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        guard Self.policy.shouldRegister else { return }
        // 注册视图容器
        kernel.viewContainer?.register(
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "mug.fill"
            ) {
                BrewManagerView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 BrewManager 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 无需额外启动逻辑
    }
}
