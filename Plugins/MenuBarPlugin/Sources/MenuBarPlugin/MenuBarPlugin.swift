import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 菜单栏插件
///
/// 提供 MenuBarProviding 服务的默认实现。
/// 负责管理所有插件的菜单栏内容和弹出项的注册、排序和查询。
@MainActor
public final class MenuBarPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar")
    nonisolated public static let emoji = "📋"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.menubar"
    public let name = "MenuBar Plugin"
    public let order = 16
public static let policy: LumiPluginPolicy = .disabled  // 核心插件，优先注册

    // MARK: - State

    private var menuBarService: DefaultMenuBarProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onReady(kernel: LumiKernel) throws {
        // 1. 注册 MenuBarService（内核服务）
        let menuBarServiceInstance = DefaultMenuBarProviding()
        kernel.registerMenuBarService(menuBarServiceInstance)
        self.menuBarService = menuBarServiceInstance

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 MenuBar 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)MenuBar 插件启动完成")
        }
    }
}
