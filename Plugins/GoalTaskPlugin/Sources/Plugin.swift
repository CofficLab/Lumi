import Foundation
import LumiCoreKit
import LumiUI
import os
import SuperLogKit
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

    public static let verbose: Bool = false

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.goal-task")

    // MARK: - Lifecycle Managed Instances

    /// 由插件生命周期管理的状态管理器实例
    @MainActor
    public static var manager: GoalStateManager?

    private static let promptService = PromptService()

    @MainActor
    public static func lifecycle(_ event: LumiPluginLifecycle, lumiCore: any LumiCoreAccessing) throws {
        switch event {
        case .didRegister:
            // 关键：不再无条件覆盖。若 manager 已存在（例如 boot 同步期 agentTools 已懒加载过），
            // 直接保留——否则会把工具/中间件已经捕获的实例替换成新的，
            // 导致写到一个库、Sidebar 从另一个库读（见 create_goal 后 UI 不刷新的根因）。
            // 目录解析优先用调用方传入的 lumiCore。
            if Self.manager == nil {
                let directory = lumiCore.storage.pluginDataDirectory(for: dataDirectoryName)
                Self.manager = try GoalStateManager(databaseRootURL: directory)
                Self.logger.info("\(Self.t)lifecycle(didRegister): 初始化 manager")
            } else {
                Self.logger.info("\(Self.t)lifecycle(didRegister): manager 已存在，保留单例")
            }

        case .willDisable:
            Self.manager = nil

        default:
            break
        }
    }

    // MARK: - Agent Tools

    /// 确保 manager 已初始化（懒加载，且全局只创建一次）。
    @MainActor
    private static func ensureManagerInitialized() throws -> GoalStateManager {
        if let manager {
            return manager
        }
        let directory = LumiCore.current?.storage.pluginDataDirectory(for: dataDirectoryName)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/\(dataDirectoryName)")
        let manager = try GoalStateManager(databaseRootURL: directory)
        Self.manager = manager
        if Self.verbose {
            Self.logger.info("\(Self.t)ensureManagerInitialized: 懒加载初始化 manager（目录=\(directory.path)）")
        }
        return manager
    }

    /// 工具/中间件/Hook 统一的 manager 取数入口：每次动态读取当前单例。
    ///
    /// 刻意不做缓存——这样即便将来生命周期时序再有变动（例如 willDisable 后重建），
    /// 工具执行时的读写也始终指向 Sidebar 读取的同一实例，避免「写一个库、读另一个库」。
    /// 返回 nil 表示 manager 尚未初始化（正常流程不应发生），调用方按需返回错误。
    @MainActor
    public static func currentManager() -> GoalStateManager? {
        manager
    }

    @MainActor
    public static func agentTools(lumiCore: any LumiCoreAccessing) throws -> [any LumiAgentTool] {
        // 提前确保 manager 存在，使首帧即可取数；工具内部仍走 currentManager() 动态读取。
        _ = try ensureManagerInitialized()
        return [
            CreateGoalTool(),
            UpdateTaskStatusTool(),
            UpdateGoalStatusTool(),
            GetGoalProgressTool(),
            AddTasksToGoalTool(),
        ]
    }

    // MARK: - Middleware

    @MainActor
    public static func sendMiddlewares(lumiCore: any LumiCoreAccessing) -> [any LumiSendMiddleware] {
        // sendMiddlewares 协议非 throws；懒加载初始化若失败，用 try? 降级——
        // 失败会经 lifecycle/agentTools 路径上报，此处不重复抛错。
        _ = try? ensureManagerInitialized()
        return [
            GoalContextMiddleware(promptService: promptService),
        ]
    }

    // MARK: - Turn Finished Hook

    @MainActor
    public static func onTurnFinished(
        lumiCore: any LumiCoreAccessing,
        conversationID: UUID,
        reason: LumiTurnEndReason
    ) async {
        await TurnFinishedHook.handle(lumiCore: lumiCore, conversationID: conversationID, reason: reason)
    }

    // MARK: - Chat Section Toolbar Bar (Bottom - Next to Verbosity)

    @MainActor
    public static func chatSectionToolbarBarItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionToolbarBarItem] {
        guard lumiCore.layoutComponent.state.chatSectionVisible,
              let chatService = lumiCore.resolveService((any LumiChatServicing).self) as? ChatService
        else {
            return []
        }

        return [
            LumiChatSectionToolbarBarItem(id: info.id, order: info.order + 1) {
                GoalToolbarButton(chatService: chatService)
            }
        ]
    }

    // MARK: - Chat Section (Sidebar)

    @MainActor
    public static func chatSectionItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionItem] {
        guard lumiCore.layoutComponent.state.chatSectionVisible,
              let coordinator = lumiCore.resolveService((any ChatSectionCoordinator).self)
        else {
            return []
        }

        return [
            LumiChatSectionItem(id: info.id, order: info.order) {
                ChatSectionView(coordinator: coordinator)
            },
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
