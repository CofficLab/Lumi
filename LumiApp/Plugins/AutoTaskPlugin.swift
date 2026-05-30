import AgentToolKit
import Foundation
import LumiCoreKit
import os
import PluginAutoTask
import SwiftUI

/// AutoTask 插件 App 侧注册适配器。
///
/// 当前 App 仍通过 ObjC runtime 扫描 `Lumi.*Plugin` 类注册插件；
/// package 中的 `PluginAutoTask.AutoTaskPlugin` 不在 `Lumi` 命名空间内，
/// 因此这里保留一个薄适配器，实际实现转发给 package 插件。
actor AutoTaskPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.auto-task")

    static let id = PluginAutoTask.AutoTaskPlugin.id
    static let displayName: String = PluginAutoTask.AutoTaskPlugin.displayName
    static let description: String = PluginAutoTask.AutoTaskPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginAutoTask.AutoTaskPlugin.description(for: language)
    }
    static let iconName: String = PluginAutoTask.AutoTaskPlugin.iconName
    static var category: PluginCategory { .agent }
    static var order: Int { PluginAutoTask.AutoTaskPlugin.order }

    static let shared = AutoTaskPlugin()

    private init() {}

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        // 注入 App 侧配置
        PluginAutoTask.AutoTaskPlugin.configuration = AppAutoTaskConfiguration()
    }

    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Agent Tools

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "自动任务清单",
                subtitle: "让助手创建、追加、更新和检查任务进度，并在侧栏显示。",
                icon: Self.iconName,
                accent: .orange,
                metrics: [
                    PluginPosterSupport.metric("Tasks", "任务"),
                    PluginPosterSupport.metric("Check", "进度"),
                ],
                rows: ["创建任务", "追加步骤", "检查进展"],
                chips: ["Agent", "任务", "侧栏"]
            ),
        ]
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            PluginAutoTask.CreateTaskTool(),
            PluginAutoTask.AppendTaskTool(),
            PluginAutoTask.UpdateTaskTool(),
            PluginAutoTask.ListTasksTool(),
            PluginAutoTask.CheckProgressTool(),
        ]
    }

    // MARK: - Send Middlewares

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        PluginAutoTask.AutoTaskPlugin.shared.sendMiddlewares().map(AnySuperSendMiddleware.init)
    }

    // MARK: - UI Contributions

    /// 右侧栏 Section 视图：任务列表
    @MainActor func addSidebarSections(context: PluginContext) -> [AnyView] {
        guard context.supportsAIChat else { return [] }
        return [AnyView(AutoTaskSidebarViewWrapper())]
    }
}

// MARK: - App Configuration

/// App 侧 AutoTask 配置实现，提供数据库路径
private struct AppAutoTaskConfiguration: AutoTaskConfiguration {
    func databaseDirectory() -> URL {
        AppConfig.getDBFolderURL()
    }

    @MainActor
    func enqueueUserMessage(_ message: ChatMessage, turnContext: TurnFinishedContext) {
        guard let appContext = turnContext as? AppTurnFinishedContext else { return }
        appContext.messageQueueVM.enqueueMessage(message)
    }
}

// MARK: - Sidebar View Wrapper

/// 包装视图：通过 @EnvironmentObject 获取当前会话 ID，转发给 package 中的 AutoTaskSidebarView
///
/// package 中的 AutoTaskSidebarView 不应直接依赖 App 侧的 WindowConversationVM，
/// 因此在 App 侧创建此包装视图来桥接。
@MainActor
private struct AutoTaskSidebarViewWrapper: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        AutoTaskSidebarView(
            conversationIdProvider: { conversationVM.selectedConversationId },
            backgroundColorProvider: {
                themeVM.activeChromeTheme.workspaceBackgroundColor()
                    .mix(with: .orange, by: 0.06)
            }
        )
    }
}
