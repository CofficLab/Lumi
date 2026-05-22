import Foundation
import ToolKit
import os
import SwiftUI

/// AutoTask 插件
///
/// 为 Agent 提供任务拆解、状态追踪和自动推进能力。
/// 解决 LLM 在执行复杂任务时"迷失方向"的核心痛点。
///
/// ## 核心功能
/// - **create_task**: 将复杂目标拆解为可执行的子任务列表
/// - **update_task**: 更新任务状态（进行中/已完成/跳过）
/// - **check_progress**: 查询当前会话的任务进度
/// - **TaskContextMiddleware**: 每轮自动注入进度，保持 Agent 全局视野
///
/// ## 工作流程
/// 1. Agent 识别复杂目标 → 调用 `create_task` 拆解为子任务
/// 2. 中间件每轮自动注入进度 → Agent 始终知道"下一步做什么"
/// 3. Agent 完成任务 → 调用 `update_task` 标记完成
/// 4. 自动推进到下一个任务
actor AutoTaskPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.auto-task")

    static let id = "AutoTask"
    static let displayName: String = "Auto Task"
    static let description: String = "Break down complex goals into trackable tasks and drive Agent auto-progress."
    static let iconName: String = "checklist"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .agent }
    static var order: Int { 90 }

    static let shared = AutoTaskPlugin()

    private init() {}

    // MARK: - Lifecycle

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Agent Tools

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        guard let conversationId = context.conversationVM?.selectedConversationId?.uuidString else {
            Self.logger.warning("\(Self.t)无法获取当前会话 ID，跳过注册 AutoTask 工具")
            return []
        }

        return [
            CreateTaskTool(conversationId: conversationId),
            UpdateTaskTool(conversationId: conversationId),
            CheckProgressTool(conversationId: conversationId),
        ]
    }

    // MARK: - Send Middlewares

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(TaskContextMiddleware())]
    }

    // MARK: - UI Contributions

    /// 右侧栏 Section 视图：任务列表
    @MainActor func addSidebarSections(activeIcon: String?) -> [AnyView] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [AnyView(AutoTaskSidebarView())]
    }
}
