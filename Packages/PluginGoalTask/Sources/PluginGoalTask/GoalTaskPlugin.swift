import KitAgentTool
import KernelCore
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageSender
import ProviderStorage
import ProviderToolManager
import SwiftUI
import LumiLoggingKit
import os

/// KernelCore implementation of the goal and task workflow.
///
/// It keeps the legacy SQLite layout inside the plugin-owned storage directory
/// so the database schema and file naming remain unchanged.
@MainActor
public final class GoalTaskPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.goal-task", category: "GoalTask")
    public let id = "com.coffic.lumi.plugin.goal-task"
    /// v4 的数据目录叫 `GoalTask`，v5 起改成 `GoalTaskPlugin`，两个都要识别。
    public let legacyDataDirectoryNames = ["GoalTaskPlugin", "GoalTask"]
    public let order = 91
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.goal-task",
        name: "GoalTask",
        description: "Goal and task management for multi-step objectives.",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    private let goalVM = GoalVM()
    private var conversationBridge: GoalTaskConversationBridge?
    private var goalChangeObserver: GoalChangeObserver?
    /// 会话被删除时清理该会话的 Goals。
    private var conversationDeletionObserver: GoalTaskConversationDeletionObserver?
    /// 「在新对话中继续」的编排器，为 `nil` 表示缺少必需的 Provider。
    private var forkCoordinator: GoalForkCoordinator?
    /// `turnFinished` 自动续跑钩子（见 `Hooks/GoalTaskTurnFinishedHook.swift`）。
    private var turnFinishedHook: GoalTaskTurnFinishedHook?
    /// `willSendToLLM` 自主执行契约注入钩子（见 `Hooks/GoalPromptInjectionHook.swift`）。
    private var promptInjectionHook: GoalPromptInjectionHook?
    private var promptInjectionHandle: (any LifecycleHookHandle)?

    public init() {}

    public func migrateData(context: PluginDataMigrationContext) throws {
        // 已经使用插件 ID 的安装由通用迁移原样复制；更早的安装把数据库放在
        // 版本根目录下的 `GoalTaskPlugin` 键里，需要单独合并到同一个内层目录。
        try PluginDataMigrationUtility.copyLegacyDirectories(
            legacyDirectoryNames: [],
            context: context
        )

        let destination = context.currentPluginDataDirectory
            .appendingPathComponent("GoalTaskPlugin", isDirectory: true)
        let fileManager = FileManager.default
        for version in context.legacyDataRootDirectories.keys.sorted(by: >) {
            // v5 的存储键是 `GoalTaskPlugin`；v4 是 `GoalTask`。两者的
            // `GoalStateManager` 都会再追加一层 `GoalTaskPlugin`，所以旧库实际位于
            // `<legacy-root>/<key>/GoalTaskPlugin/goals.sqlite`。
            // 当前读取路径是 `<current>/GoalTaskPlugin/goals.sqlite`：必须合并内层目录。
            // 合并外层会把库再往下套一层，升级后旧目标看起来就像被清空。
            for legacyName in ["GoalTaskPlugin", "GoalTask"] {
                guard let legacyRoot = context.legacyPluginDataDirectory(
                    named: legacyName,
                    in: version
                ), fileManager.fileExists(atPath: legacyRoot.path) else {
                    continue
                }
                let inner = legacyRoot.appendingPathComponent("GoalTaskPlugin", isDirectory: true)
                let source = fileManager.fileExists(atPath: inner.path) ? inner : legacyRoot
                try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
                try PluginDataMigrationUtility.mergeDirectoryContents(
                    from: source,
                    to: destination,
                    fileManager: fileManager
                )
            }
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            Plugin.logger.error("🎯 Storage service not available")
            return
        }

        // Store GoalTask data under the plugin's own ID, consistent with the
        // other plugins. GoalStateManager retains its inner database directory
        // to keep the SQLite layout stable within this plugin-owned directory.
        Plugin._sharedManager = try GoalStateManager(
            databaseRootURL: storage.pluginDataDirectory(for: id)
        )

        guard let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.t) ConversationManaging not found")
            return
        }
        let bridge = GoalTaskConversationBridge(conversations)
        conversationBridge = bridge
        if let messageSender = kernel.resolveProvider((any MessageSendingProviding).self) {
            forkCoordinator = GoalForkCoordinator(
                capability: GoalForkCapabilityAdapter(
                    conversations: conversations,
                    messageSender: messageSender
                )
            )
        } else {
            Self.logger.error("\(Self.t) MessageSendingProviding not found, fork action disabled")
        }
        goalVM.updateCurrentConversationID(bridge.selectedConversationID)
        goalChangeObserver = GoalChangeObserver { [weak self] conversationID in
            self?.goalVM.refreshIfCurrentConversation(conversationID)
        }
        conversationDeletionObserver = GoalTaskConversationDeletionObserver(
            conversations: conversations
        ) { conversationID in
            guard let manager = Plugin.currentManager() else {
                Self.logger.error(
                    "\(Self.t)Goal manager unavailable; goals for conversation \(conversationID) were not deleted"
                )
                return
            }
            do {
                try await manager.deleteAllGoals(conversationId: conversationID.uuidString)
            } catch {
                Self.logger.error(
                    "\(Self.t)Failed to delete goals for conversation \(conversationID): \(error.localizedDescription)"
                )
            }
        }

        // 先把编排器固化为局部常量再进闭包:直接捕获 `self.forkCoordinator`
        // 会让 ChatSection 的构建时机与 Provider 注册顺序耦合,早于
        // `MessageSendingProviding` 就绪时将永久拿到 nil。
        let coordinator = forkCoordinator

        kernel.resolveProvider((any ChatSectionProviding).self)?.addItems([
            ChatSectionItem(
                id: "\(id).active-goal",
                placement: .stack,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) { [goalVM, bridge, coordinator] in
                GoalTaskChatSectionView(
                    viewModel: goalVM,
                    conversationBridge: bridge,
                    forkCoordinator: coordinator
                )
            }
        ])
        kernel.resolveProvider((any ChatSectionProviding).self)?.addBarItems([
            ChatSectionBarItem(id: "\(id).toolbar-button", placement: .toolbarTrailing) { [goalVM, coordinator] in
                GoalToolbarButton(
                    viewModel: goalVM,
                    forkCoordinator: coordinator
                )
            }
        ])

        let tools: [any SuperAgentTool] = [
            CreateGoalV2Tool(conversations: conversations),
            AddTasksToGoalV2Tool(),
            GetGoalProgressV2Tool(),
            UpdateGoalStatusV2Tool(),
            UpdateTaskStatusV2Tool(),
        ]
        let toolManager = kernel.resolveProvider((any ToolManagerProviding).self)
        tools.forEach { toolManager?.add($0, pluginID: id) }

        guard let hooks = kernel.resolveProvider((any LifecycleHooksProviding).self),
              let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self),
              let messages = kernel.resolveProvider((any MessageManaging).self) else { return }
        let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop, messages: messages)
        turnFinishedHook = hook
        hooks.addTurnFinishedHook { [weak hook] context in
            await hook?.apply(to: context)
        }

        // 每轮注入 goal 自主执行契约与进度。没有这条契约，LLM 只知道
        // 有个 goal 存在，却不知道该自己走完 —— 这正是它反复停下来问用户的原因。
        let injectionHook = GoalPromptInjectionHook()
        promptInjectionHook = injectionHook
        promptInjectionHandle = hooks.addWillSendToLLMHook { [weak injectionHook] context in
            guard let injectionHook else { return context }
            return await injectionHook.apply(to: context)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?.removeItem(id: "\(id).active-goal")
        kernel.resolveProvider((any ChatSectionProviding).self)?.removeBarItem(id: "\(id).toolbar-button")
        [CreateGoalV2Tool.toolName, AddTasksToGoalV2Tool.toolName, GetGoalProgressV2Tool.toolName,
         UpdateGoalStatusV2Tool.toolName, UpdateTaskStatusV2Tool.toolName]
            .forEach { kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: $0) }
        conversationBridge?.cancel()
        conversationBridge = nil
        goalChangeObserver?.cancel()
        goalChangeObserver = nil
        conversationDeletionObserver?.cancel()
        conversationDeletionObserver = nil
        forkCoordinator = nil
        turnFinishedHook = nil
        promptInjectionHandle?.cancel()
        promptInjectionHandle = nil
        promptInjectionHook = nil
        Plugin._sharedManager = nil
    }
}

private struct GoalTaskChatSectionView: View {
    @ObservedObject var viewModel: GoalVM
    @ObservedObject var conversationBridge: GoalTaskConversationBridge
    let forkCoordinator: GoalForkCoordinator?

    var body: some View {
        SidebarView(viewModel: viewModel, forkCoordinator: forkCoordinator)
            .task(id: conversationBridge.selectedConversationID) {
                viewModel.updateCurrentConversationID(conversationBridge.selectedConversationID)
                await viewModel.refresh()
            }
    }
}
