import LumiKernel
import SuperLogKit
import LumiUI
import os
import SwiftUI

/// Disk Manager 插件
///
/// 向 LumiKernel 注册磁盘管理功能：
/// - ViewContainer：侧边栏磁盘管理视图
@MainActor
public final class DiskManagerPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.disk-manager")
    public nonisolated static let emoji = "💿"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.disk-manager"
    public let name = "Disk Manager"
    public let order = 44
public static let policy: LumiPluginPolicy = .disabled

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 注册视图容器
        kernel.viewContainer?.register(
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "internaldrive"
            ) {
                DiskManagerView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 DiskManager 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 无需额外启动逻辑
    }
}
