import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 面板插件
///
/// 提供 PanelProviding 服务的默认实现。
/// 负责管理所有插件的面板项（顶部标题栏、底部标签、侧边栏标签）的注册、排序和查询。
@MainActor
public final class PanelPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.panel")
    nonisolated public static let emoji = "🧩"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.panel"
    public let name = "Panel Plugin"
    public let order = 18
public static let policy: LumiPluginPolicy = .disabled  // 核心插件，优先注册

    // MARK: - State

    private var panelService: DefaultPanelProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 PanelService（内核服务）
        let panelServiceInstance = DefaultPanelProviding()
        kernel.registerPanelService(panelServiceInstance)
        self.panelService = panelServiceInstance

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Panel 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)Panel 插件启动完成")
        }
    }
}
