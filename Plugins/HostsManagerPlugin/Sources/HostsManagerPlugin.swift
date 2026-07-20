import LumiKernel
import SuperLogKit
import LumiUI
import os
import SwiftUI

/// Hosts Manager 插件
///
/// 向 LumiKernel 注册 hosts 文件管理功能：
/// - ViewContainer：侧边栏 hosts 管理视图
@MainActor
public final class HostsManagerPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.hosts-manager")
    public nonisolated static let emoji = "📝"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.hosts-manager"
    public let name = "Hosts Manager"
    public let order = 21
public static let policy: LumiPluginPolicy = .disabled

    public var policy: LumiPluginPolicy { .disabled }

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
                systemImage: "list.bullet.rectangle"
            ) {
                HostsManagerView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 HostsManager 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 无需额外启动逻辑
    }
}
