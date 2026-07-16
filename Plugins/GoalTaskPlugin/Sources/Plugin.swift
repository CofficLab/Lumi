import Foundation
import LumiCoreKit
import LumiChatKit
import LumiUI
import SuperLogKit
import os
import SwiftUI

/// GoalTask 插件：目标导向的任务管理，支持并行执行
public enum GoalTaskPlugin: LumiPlugin, SuperLog {
    
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
    
    public static let emoji = "🎯"
    
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
    
    /// 确保 manager 已初始化（懒加载）
    @MainActor
    private static func ensureManagerInitialized() -> GoalStateManager {
        if let manager {
            return manager
        }
        let directory = LumiCore.current?.pluginDataDirectory(for: dataDirectoryName)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/\(dataDirectoryName)")
        let manager = GoalStateManager(databaseRootURL: directory)
        Self.manager = manager
        Self.logger.info("\(Self.t)agentTools: 懒加载初始化 manager")
        return manager
    }
    
    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        let manager = ensureManagerInitialized()
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
        let manager = ensureManagerInitialized()
        return [
            GoalContextMiddleware(manager: manager, promptService: promptService)
        ]
    }
    
    // MARK: - Turn Finished Hook
    
    @MainActor
    public static func onTurnFinished(
        context: LumiPluginContext,
        conversationID: UUID,
        reason: LumiTurnEndReason
    ) async {
        await TurnFinishedHook.handle(context: context, conversationID: conversationID, reason: reason)
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
