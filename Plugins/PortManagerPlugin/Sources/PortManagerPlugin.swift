import Foundation
import LumiKernel
import LumiUI
import ShellKit
import SuperLogKit
import SwiftUI
import os

/// Port Manager Plugin
///
/// Inspect local listening ports.
@MainActor
public final class PortManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.port-manager")
    nonisolated public static let emoji = "🔌"
    nonisolated public static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.port-manager"
    public let name = "Port Manager"
    public let order = 43
public static let policy: LumiPluginPolicy = .disabled

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        guard Self.policy.shouldRegister else { return }
        kernel.viewContainer?.register(
            ViewContainerItem(
                id: id,
                title: "Port Manager",
                systemImage: "arrow.up.arrow.down.circle"
            ) {
                PortManagerView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Port Manager 视图容器到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)Port Manager 插件启动完成")
        }
    }
}