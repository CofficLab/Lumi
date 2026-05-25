import AgentToolKit
import Foundation
import SuperLogKit
import os

/// AutoTask 插件 Package 侧主入口
///
/// 提供 Agent 工具（create_task、append_task、update_task、list_tasks、check_progress）
/// 和任务上下文中间件。
///
/// App 侧通过薄适配器注册此插件，实际实现转发给 package。
public final class AutoTaskPlugin: SuperLog {
    nonisolated public static let emoji = "📋"
    nonisolated public static let verbose: Bool = true
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.auto-task")

    // MARK: - Plugin Properties

    public static let id = "AutoTask"
    public static let displayName: String = "Auto Task"
    public static let description: String = "Break down complex goals into trackable tasks and drive Agent auto-progress."
    public static let iconName: String = "checklist"
    public static let isConfigurable: Bool = false
    public static let enable: Bool = true
    public static var order: Int { 90 }

    // MARK: - Configuration

    /// 插件配置（由 App 侧注册文件注入）
    public static var configuration: AutoTaskConfiguration = DefaultAutoTaskConfiguration()

    private init() {}

    // MARK: - Agent Tools

    public func agentTools() -> [any SuperAgentTool] {
        return [
            CreateTaskTool(),
            AppendTaskTool(),
            UpdateTaskTool(),
            ListTasksTool(),
            CheckProgressTool(),
        ]
    }

    // MARK: - Send Middlewares

    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(TaskContextMiddleware())]
    }
}

// MARK: - Default Configuration

/// 默认配置（fallback，实际运行时由 App 侧覆盖）
private struct DefaultAutoTaskConfiguration: AutoTaskConfiguration {
    func databaseDirectory() -> URL {
        // Fallback：使用标准 App Support 目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("db", isDirectory: true)
    }
}
