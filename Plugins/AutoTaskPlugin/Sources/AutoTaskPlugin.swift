import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import os
import SwiftUI

/// AutoTask 插件 Package 侧主入口
///
/// 提供 Agent 工具（create_task、append_task、update_task、list_tasks、check_progress）
/// 和任务上下文中间件。
///
/// App 侧通过薄适配器注册此插件，实际实现转发给 package。
public actor AutoTaskPlugin: SuperPlugin, SuperLog {
    nonisolated public static let emoji = "📋"
    nonisolated public static let verbose: Bool = true
    nonisolated public static let policy: PluginPolicy = .alwaysOn
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.auto-task")

    // MARK: - Plugin Properties

    public static let id = "AutoTask"
    public static let displayName: String = "Auto Task"
    public static let description: String = "Break down complex goals into trackable tasks and drive Agent auto-progress."
    public static let iconName: String = "checklist"
    public static var order: Int { 90 }
    public static var category: PluginCategory { .agent }

    // MARK: - Configuration

    /// 插件配置（由 App 侧注册文件注入）
    nonisolated(unsafe) public static var configuration: any AutoTaskConfiguration = DefaultAutoTaskConfiguration()

    public static let shared = AutoTaskPlugin()

    private init() {}

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        AutoTaskRuntimeBridge.databaseDirectoryProvider = context.databaseDirectory
        AutoTaskRuntimeBridge.enqueueUserMessage = { message, turnContext in
            context.enqueueUserMessage(message, turnContext)
        }
        Self.configuration = RuntimeAutoTaskConfiguration()
    }

    // MARK: - Agent Tools

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            CreateTaskTool(),
            AppendTaskTool(),
            UpdateTaskTool(),
            ListTasksTool(),
            CheckProgressTool(),
        ]
    }

    // MARK: - Send Middlewares

    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [
            AnySuperSendMiddleware(TaskContextMiddleware()),
            AnySuperSendMiddleware(AutoTaskTurnCheckMiddleware()),
        ]
    }

    // MARK: - UI Contributions

    @MainActor
    public func addSidebarSections(context: PluginContext) -> [AnyView] {
        guard context.showChat else { return [] }
        return [AnyView(AutoTaskSidebarViewWrapper())]
    }
}

@MainActor
private struct AutoTaskSidebarViewWrapper: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        AutoTaskSidebarView(
            conversationIdProvider: { conversationVM.selectedConversationId },
            backgroundColorProvider: {
                themeVM.activeChromeTheme.workspaceBackgroundColor()
            }
        )
    }
}

// MARK: - Default Configuration

private enum AutoTaskRuntimeBridge {
    nonisolated(unsafe) static var databaseDirectoryProvider: @Sendable () -> URL = {
        DefaultAutoTaskConfiguration().databaseDirectory()
    }
    nonisolated(unsafe) static var enqueueUserMessage: @MainActor (ChatMessage, TurnFinishedContext) -> Void = { _, _ in }
}

private struct RuntimeAutoTaskConfiguration: AutoTaskConfiguration {
    func databaseDirectory() -> URL {
        AutoTaskRuntimeBridge.databaseDirectoryProvider()
    }

    @MainActor
    func enqueueUserMessage(_ message: ChatMessage, turnContext: TurnFinishedContext) {
        AutoTaskRuntimeBridge.enqueueUserMessage(message, turnContext)
    }
}

/// 默认配置（fallback，实际运行时由 App 侧覆盖）
private struct DefaultAutoTaskConfiguration: AutoTaskConfiguration {
    func databaseDirectory() -> URL {
        // Fallback：使用标准 App Support 目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("db", isDirectory: true)
    }

    @MainActor
    func enqueueUserMessage(_ message: ChatMessage, turnContext: TurnFinishedContext) {}
}
