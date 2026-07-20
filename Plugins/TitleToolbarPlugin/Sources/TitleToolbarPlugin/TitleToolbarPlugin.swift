import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 标题栏工具栏插件
///
/// 提供 TitleToolbarProviding 服务的默认实现。
/// 负责管理所有插件的标题栏工具栏项的注册、排序和查询。
@MainActor
public final class TitleToolbarPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.title-toolbar")
    nonisolated public static let emoji = "🧰"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.title-toolbar"
    public let name = "TitleToolbar Plugin"
    public let order = 16
public static let policy: LumiPluginPolicy = .disabled  // 核心插件，优先注册

    // MARK: - State

    private var titleToolbarService: DefaultTitleToolbarProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 TitleToolbarService（内核服务）
        let titleToolbarServiceInstance = DefaultTitleToolbarProviding()
        kernel.registerTitleToolbarService(titleToolbarServiceInstance)
        self.titleToolbarService = titleToolbarServiceInstance

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 TitleToolbar 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)TitleToolbar 插件启动完成")
        }
    }
}
