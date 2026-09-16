import KitAgentTool
import KernelCore
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderLifecycleHooks
import ProviderStorage
import ProviderToolManager
import SwiftUI
import KitSuperLog
import os

/// KernelCore implementation of the goal and task workflow.
///
/// It keeps the legacy SQLite layout inside the plugin-owned storage directory
/// so the database schema and file naming remain unchanged.
@MainActor
public final class GoalTaskSuperPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.goal-task", category: "GoalTask")
    public let id = "com.coffic.lumi.plugin.goal-task"
    public let legacyDataDirectoryNames = ["GoalTaskPlugin"]
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
    /// `turnFinished` 自动续跑钩子（见 `Hooks/GoalTaskTurnFinishedHook.swift`）。
    private var turnFinishedHook: GoalTaskTurnFinishedHook?

    public init() {}

    public func migrateData(context: PluginDataMigrationContext) throws {
        // A v5 install that already used the plugin ID keeps the historical
        // inner `GoalTaskPlugin` database directory; the generic migration
        // preserves that layout. Older installs used `GoalTaskPlugin` as the
        // version-root child, so that source must be copied into the same
        // inner directory rather than flattened into the plugin ID root.
        try PluginDataMigrationUtility.copyLegacyDirectories(
            legacyDirectoryNames: [],
            context: context
        )

        let destination = context.currentPluginDataDirectory
            .appendingPathComponent("GoalTaskPlugin", isDirectory: true)
        let fileManager = FileManager.default
        for version in context.legacyDataRootDirectories.keys.sorted(by: >) {
            guard let source = context.legacyPluginDataDirectory(
                named: "GoalTaskPlugin",
                in: version
            ), fileManager.fileExists(atPath: source.path) else {
                continue
            }
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            try PluginDataMigrationUtility.mergeDirectoryContents(
                from: source,
                to: destination,
                fileManager: fileManager
            )
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
        goalVM.updateCurrentConversationID(bridge.selectedConversationID)
        goalChangeObserver = GoalChangeObserver { [weak self] conversationID in
            self?.goalVM.refreshIfCurrentConversation(conversationID)
        }

        kernel.resolveProvider((any ChatSectionProviding).self)?.addItems([
            ChatSectionItem(
                id: "\(id).active-goal",
                placement: .stack,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) { [goalVM, bridge] in
                GoalTaskChatSectionView(viewModel: goalVM, conversationBridge: bridge)
            }
        ])
        kernel.resolveProvider((any ChatSectionProviding).self)?.addBarItems([
            ChatSectionBarItem(id: "\(id).toolbar-button", placement: .toolbarTrailing) {
                GoalToolbarButton(viewModel: self.goalVM)
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
              let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self) else { return }
        let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop)
        turnFinishedHook = hook
        hooks.addTurnFinishedHook { [weak hook] context in
            await hook?.apply(to: context)
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
        turnFinishedHook = nil
        Plugin._sharedManager = nil
    }
}

private struct GoalTaskChatSectionView: View {
    @ObservedObject var viewModel: GoalVM
    @ObservedObject var conversationBridge: GoalTaskConversationBridge

    var body: some View {
        SidebarView(viewModel: viewModel)
            .task(id: conversationBridge.selectedConversationID) {
                viewModel.updateCurrentConversationID(conversationBridge.selectedConversationID)
                await viewModel.refresh()
            }
    }
}
