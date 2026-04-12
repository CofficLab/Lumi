import Foundation
import MagicKit
import SwiftUI
import os

/// Agent Context Sync Plugin: 监听项目变化并同步上下文到 Agent
///
/// 功能：
/// - 监听 projectVM 中当前项目路径的变化
/// - 当项目变化时，向当前对话添加系统消息，告知大模型用户切换了项目
actor AgentContextSyncPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.context-sync")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🔄"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "AgentContextSync"
    static let displayName: String = String(localized: "Context Sync", table: "AgentContextSync")
    static let description: String = String(localized: "Sync project context to conversation", table: "AgentContextSync")
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

    // MARK: - Views

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ContextSyncOverlay(content: content()))
    }

    @MainActor
    func agentTools() -> [AgentTool] { [] }

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] { [] }

    @MainActor
    func sendMiddlewares() -> [AnySendMiddleware] { [] }
}