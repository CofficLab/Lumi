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
    static let iconName: String = PluginAutoTask.AutoTaskPlugin.iconName
    static let isConfigurable: Bool = PluginAutoTask.AutoTaskPlugin.isConfigurable
    static let enable: Bool = PluginAutoTask.AutoTaskPlugin.enable
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
        [AnySuperSendMiddleware(AutoTaskTurnCheckMiddleware())]
    }

    // MARK: - UI Contributions

    /// 右侧栏 Section 视图：任务列表
    @MainActor func addSidebarSections(activeIcon: String?) -> [AnyView] {
        guard ChatSurfaceActivation.isActive(activeIcon) else { return [] }
        return [AnyView(
            AutoTaskSidebarView(
                conversationIdProvider: { nil },
                backgroundColorProvider: { .clear }
            )
        )]
    }
}

// MARK: - App Configuration

/// App 侧 AutoTask 配置实现，提供数据库路径
private struct AppAutoTaskConfiguration: AutoTaskConfiguration {
    func databaseDirectory() -> URL {
        AppConfig.getDBFolderURL()
    }
}
