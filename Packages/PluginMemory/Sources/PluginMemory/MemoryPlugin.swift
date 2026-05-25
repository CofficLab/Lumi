import AgentToolKit
import Foundation
import LumiCoreKit
import MemoryKit
import SuperLogKit
import os

/// Memory Plugin：持久化记忆系统。
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
public actor MemoryPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.memory")

    public nonisolated static let emoji = "🧠"
    public nonisolated static let verbose: Bool = true

    public static let id: String = "Memory"
    public static let displayName: String = PluginMemoryLocalization.string("Memory")
    public static let description: String = PluginMemoryLocalization.string("Persistent memory system for cross-session context")
    public static let iconName: String = "brain.head.profile"
    public static let isConfigurable: Bool = false
    public static let enable: Bool = true
    public static var category: PluginCategory { .agent }
    public static var order: Int { 15 }

    nonisolated public var instanceLabel: String { Self.id }

    public static let shared = MemoryPlugin()

    /// 配置，由 App 层在初始化时设置
    nonisolated(unsafe) public static var config: MemoryPluginConfig = .default

    private init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ MemoryPlugin 初始化完成")
        }
    }

    // MARK: - Lifecycle

    nonisolated public func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t)📝 MemoryPlugin 已注册")
        }
    }

    nonisolated public func onEnable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ MemoryPlugin 已启用")
        }
    }

    nonisolated public func onDisable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)⛔️ MemoryPlugin 已禁用")
        }
    }

    // MARK: - Agent Tools

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            SaveMemoryTool(),
            RecallMemoryTool(),
            ListMemoriesTool(),
            DeleteMemoryTool(),
        ]
    }
}

enum PluginMemoryLocalization {
    static let table = "Memory"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }
}
