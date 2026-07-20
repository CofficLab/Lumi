import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Netto Firewall Plugin
///
/// Manage network permissions for macOS applications.
@MainActor
public final class NettoPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.netto")
    nonisolated public static let emoji = "🛡️"
    nonisolated public static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.netto"
    public let name = "Netto Firewall Plugin"
    public let order = 99
public static let policy: LumiPluginPolicy = .disabled

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 注册视图容器（order 自动从插件继承）
        kernel.viewContainer?.register(
            ViewContainerItem(
                id: id,
                title: "Netto Firewall",
                systemImage: "shield.lefthalf.filled"
            ) {
                NettoDashboardView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Netto Firewall 视图容器到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)Netto Firewall 插件启动完成")
        }
    }
}