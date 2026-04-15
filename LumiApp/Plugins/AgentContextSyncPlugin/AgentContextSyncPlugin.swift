import Foundation
import MagicKit
import SwiftUI
import os

/// Agent Context Sync Plugin: 在消息发送时注入项目上下文
///
/// 功能：
/// - 通过中间件在发送消息时注入当前项目信息
/// - 不再将上下文保存到数据库，而是作为临时提示词注入
actor AgentContextSyncPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.context-sync")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🔄"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "AgentContextSync"
    static let displayName: String = String(localized: "Context Sync", table: "AgentContextSync")
    static let description: String = String(
        localized: "Sync project context to conversation", table: "AgentContextSync")
    static let iconName: String = "arrow.triangle.2.circlepath"
    static let isConfigurable: Bool = false
    static var order: Int { 1 }

    nonisolated var instanceLabel: String {
        Self.id
    }

    static let shared = AgentContextSyncPlugin()

    init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ AgentContextSyncPlugin 初始化完成")
        }
    }

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t)📝 AgentContextSyncPlugin 已注册")
        }
    }

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(self.t)✅ AgentContextSyncPlugin 已启用")
        }
    }

    nonisolated func onDisable() {
        if Self.verbose {
            Self.logger.info("\(self.t)⛔️ AgentContextSyncPlugin 已禁用")
        }
    }

    // MARK: - Middlewares

    @MainActor
    func sendMiddlewares() -> [AnySendMiddleware] {
        [AnySendMiddleware(AgentContextSyncSendMiddleware())]
    }
}
