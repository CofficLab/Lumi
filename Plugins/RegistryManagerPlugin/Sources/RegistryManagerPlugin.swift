import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Registry Manager Plugin
///
/// Manage Lumi registries.
@MainActor
public final class RegistryManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.registry-manager")
    nonisolated public static let emoji = "🔄"
    nonisolated public static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.registry-manager"
    public let name = "Registry Manager"
    public let order = 80

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        kernel.registerViewContainer(
            ViewContainerItem(
                id: id,
                title: "Registry Manager",
                systemImage: "arrow.triangle.2.circlepath"
            ) {
                RegistryManagerView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Registry Manager 视图容器到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)Registry Manager 插件启动完成")
        }
    }
}