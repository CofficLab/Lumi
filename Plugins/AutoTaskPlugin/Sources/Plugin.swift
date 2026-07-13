import LumiChatKit
import LumiCoreKit
import LumiUI
import os
import SwiftUI

/// AutoTask 插件：任务拆解、进度跟踪与 Agent 自动推进。
public enum AutoTaskPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "checklist"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.auto-task",
        displayName: LumiPluginLocalization.string("Auto Task", bundle: .module),
        description: LumiPluginLocalization.string("Break down complex goals into trackable tasks and drive Agent auto-progress.", bundle: .module),
        order: 90
    )

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.auto-task")
    nonisolated(unsafe) public static var configuration: any Configuration = DefaultConfiguration()

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        bootstrapFromLumiCoreIfNeeded()
        bootstrapTurnCheck { context.resolve(LumiChatServicing.self) }
        return [TaskContextChatMiddleware()]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        bootstrapFromLumiCoreIfNeeded()
        return [
            CreateTaskTool(),
            AppendTaskTool(),
            UpdateTaskTool(),
            ListTasksTool(),
            CheckProgressTool(),
        ]
    }

    @MainActor
    public static func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
        guard context.showsChatSection,
              let coordinator = context.resolve(ChatSectionCoordinator.self)
        else {
            return []
        }

        return [
            LumiChatSectionItem(id: info.id, order: info.order) {
                ChatSectionView(coordinator: coordinator)
            }
        ]
    }
}

private struct ChatSectionView: View {
    @LumiTheme private var theme
    @ObservedObject var coordinator: ChatSectionCoordinator

    var body: some View {
        SidebarView(
            conversationIdProvider: { coordinator.selectedConversationID },
            backgroundColorProvider: {
                theme.background.opacity(0.94)
            }
        )
    }
}

private struct DefaultConfiguration: Configuration {
    func databaseDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("db", isDirectory: true)
    }
}
