import Foundation
import SwiftUI
import AgentToolKit
import os

/// Memory Plugin: 持久化记忆系统
///
/// 参考 Claude Code 的 memdir 系统设计，让 Lumi 能跨会话记住：
/// - 用户角色、偏好和知识水平
/// - 用户对 Lumi 行为的反馈和指导
/// - 项目级上下文（目标、决策、非代码可得信息）
/// - 外部系统指针（Linear/Grafana/文档链接等）
///
/// ## 核心组件
/// - **MemoryStorageService**: 文件 CRUD + 索引维护
/// - **MemoryRetrievalService**: 本地关键词匹配检索
/// - **MemoryContextSuperSendMiddleware**: 发送时注入记忆提示词
/// - **4 个 Agent Tools**: save/recall/list/delete memory
actor MemoryPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.memory")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🧠"
    nonisolated static let verbose: Bool = true
    static let id: String = "Memory"
    static let displayName: String = String(localized: "Memory", table: "Memory")
    static let description: String = String(
        localized: "Persistent memory system for cross-session context", table: "Memory")
    static let iconName: String = "brain.head.profile"
    static let isConfigurable: Bool = true
    static let enable: Bool = true
    static var category: PluginCategory { .agent }
    static var order: Int { 15 }

    nonisolated var instanceLabel: String {
        Self.id
    }

    static let shared = MemoryPlugin()

    init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ MemoryPlugin 初始化完成")
        }
    }

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t)📝 MemoryPlugin 已注册")
        }
    }

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ MemoryPlugin 已启用")
        }
    }

    nonisolated func onDisable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)⛔️ MemoryPlugin 已禁用")
        }
    }

    // MARK: - Agent Tools

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            SaveMemoryTool(),
            RecallMemoryTool(),
            ListMemoriesTool(),
            DeleteMemoryTool(),
        ]
    }

    // MARK: - Send Middlewares

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(MemoryContextSuperSendMiddleware())]
    }

    // MARK: - Settings View

    @MainActor
    func addSettingsView() -> AnyView? {
        AnyView(MemorySettingsView())
    }
}
