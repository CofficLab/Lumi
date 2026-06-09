import AgentToolKit
import LumiChatKit
import LumiCoreKit
import LumiUI
import os
import SwiftUI

/// AutoTask 插件：任务拆解、进度跟踪与 Agent 自动推进。
public enum AutoTaskPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "checklist"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.auto-task",
        displayName: "Auto Task",
        description: "Break down complex goals into trackable tasks and drive Agent auto-progress.",
        order: 90
    )

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.auto-task")
    nonisolated(unsafe) public static var configuration: any AutoTaskConfiguration = DefaultAutoTaskConfiguration()

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        bootstrapFromLumiCoreIfNeeded()
        return [TaskContextChatMiddleware()]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        bootstrapFromLumiCoreIfNeeded()
        return [
            CreateTaskTool().asLumiAgentTool(),
            AppendTaskTool().asLumiAgentTool(),
            UpdateTaskTool().asLumiAgentTool(),
            ListTasksTool().asLumiAgentTool(),
            CheckProgressTool().asLumiAgentTool(),
        ]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.activeSectionID == LumiChatPanelSection.id,
              let chatService = context.resolve((any LumiChatServicing).self)
        else {
            return []
        }

        return [
            LumiStatusBarItem(
                id: "\(info.id).tasks",
                title: String(localized: "Tasks", bundle: .module),
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    AutoTaskStatusBarView(chatService: chatService)
                }
            )
        ]
    }
}

private struct DefaultAutoTaskConfiguration: AutoTaskConfiguration {
    func databaseDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("db", isDirectory: true)
    }
}
