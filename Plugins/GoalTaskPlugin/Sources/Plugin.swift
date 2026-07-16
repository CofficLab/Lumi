import Foundation
import LumiCoreKit
import LumiChatKit
import LumiUI
import SuperLogKit
import os
import SwiftUI

/// GoalTask 插件：目标导向的任务管理，支持并行执行
public enum GoalTaskPlugin: LumiPlugin {
    
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.goal-task",
        displayName: "Goal & Task",
        description: "Goal-oriented task management with parallel execution support",
        order: 91,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "target"
    )
    
    /// 插件数据存储的子目录名称
    public static let dataDirectoryName = "GoalTask"
    
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.goal-task")
    
    // MARK: - Lifecycle Managed Instances
    
    /// 由插件生命周期管理的状态管理器实例
    @MainActor
    public static var manager: GoalStateManager?
    
    private static let promptService = PromptService()
    
    @MainActor
    public static func lifecycle(_ event: LumiPluginLifecycle) {
        switch event {
        case .didRegister:
            let directory = LumiCore.current?.pluginDataDirectory(for: dataDirectoryName)
                ?? FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/\(dataDirectoryName)")
            Self.manager = GoalStateManager(databaseRootURL: directory)
            
        case .willDisable:
            Self.manager = nil
            
        default:
            break
        }
    }
    
    // MARK: - Agent Tools
    
    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        guard let manager else {
            Self.logger.warning("agentTools: manager 未初始化，返回空工具列表")
            return []
        }
        return [
            CreateGoalTool(manager: manager),
            UpdateTaskStatusTool(manager: manager),
            UpdateGoalStatusTool(manager: manager),
            GetGoalProgressTool(manager: manager),
            AddTasksToGoalTool(manager: manager)
        ]
    }
    
    // MARK: - Middleware
    
    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        guard let manager else {
            return []
        }
        return [
            GoalContextMiddleware(manager: manager, promptService: promptService)
        ]
    }
    
    // MARK: - Chat Section (Sidebar)
    
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

// MARK: - Chat Section View

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