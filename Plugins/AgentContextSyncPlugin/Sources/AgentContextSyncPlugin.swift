import Foundation
import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

/// Agent Context Sync Plugin: 在消息发送时注入项目上下文
///
/// 功能：
/// - 通过中间件在发送消息时注入当前项目信息
/// - 不再将上下文保存到数据库，而是作为临时提示词注入
public actor AgentContextSyncPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.context-sync")

    // MARK: - Plugin Properties

    public nonisolated static let emoji = "🔄"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "AgentContextSync"
    public static let displayName: String = String(localized: "Context Sync", table: "AgentContextSync")
    public static let description: String = String(
        localized: "Sync project context to conversation", table: "AgentContextSync")
    public static let iconName: String = "arrow.triangle.2.circlepath"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 1 }

    public nonisolated var instanceLabel: String {
        Self.id
    }

    public static let shared = AgentContextSyncPlugin()

    public init() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)✅ AgentContextSyncPlugin 初始化完成")
            }
        }
    }

    // MARK: - Lifecycle

    public nonisolated func onRegister() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)📝 AgentContextSyncPlugin 已注册")
            }
        }
    }

    public nonisolated func onEnable() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t)✅ AgentContextSyncPlugin 已启用")
            }
        }
    }

    public nonisolated func onDisable() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t)⛔️ AgentContextSyncPlugin 已禁用")
            }
        }
    }

    // MARK: - Middlewares

    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        []
    }
}
