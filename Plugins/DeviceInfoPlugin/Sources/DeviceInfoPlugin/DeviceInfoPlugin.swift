import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 设备信息内核插件
///
/// 向 LumiKernel 注册设备信息相关的视图容器。
@MainActor
public final class DeviceInfoPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.device-info")
    nonisolated public static let emoji = "📊"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.device-info"
    public let name = "Device Info Plugin"
    public let order = 200
public static let policy: LumiPluginPolicy = .disabled  // 功能插件

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onReady(kernel: LumiKernel) throws {
        guard Self.policy.shouldRegister else { return }
        // 注册主视图容器（order 自动从插件继承）
        kernel.viewContainer?.register(
            ViewContainerItem(
                id: id,
                title: "Device Info",
                systemImage: "macbook.and.iphone"
            ) {
                DeviceInfoView()
            }
        )

        // 注册菜单栏内容（order 自动从插件继承）
        kernel.menuBar?.registerMenuBarContent(
            MenuBarContentItem(
                id: "\(id).metrics"
            ) {
                DeviceInfoMenuBarContentView()
            }
        )

        // 注册菜单栏弹出项（order 自动从插件继承）
        kernel.menuBar?.registerMenuBarPopup(
            MenuBarPopupItem(
                id: "\(id).cpu"
            ) {
                DeviceInfoMenuBarPopupView()
            }
        )

        kernel.menuBar?.registerMenuBarPopup(
            MenuBarPopupItem(
                id: "\(id).memory"
            ) {
                MemoryMenuBarPopupView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 DeviceInfo 视图容器到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 启动监控服务（如果需要）
        if Self.verbose {
            Self.logger.info("\(Self.t)DeviceInfo 插件启动完成")
        }
    }
}