import LumiKernel
import SuperLogKit
import LumiUI
import os
import SwiftUI

/// Quick Launcher 插件
///
/// 向 LumiKernel 注册快速启动器：
/// - MenuBarPopup：菜单栏快速启动弹窗
@MainActor
public final class QuickLauncherPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.quicklauncher")
    public nonisolated static let emoji = "🚀"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.quick-launcher"
    public let name = "Quick Launcher"
    public let order = 8
public static let policy: LumiPluginPolicy = .disabled

    public var policy: LumiPluginPolicy { .disabled }

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onReady(kernel: LumiKernel) throws {
        // 注册菜单栏弹窗（order 自动从插件继承）
        kernel.menuBar?.registerMenuBarPopup(
            MenuBarPopupItem(id: "\(id).launcher") {
                QuickLauncherMenuBarPopupView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 QuickLauncher 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 无需额外启动逻辑
    }
}
