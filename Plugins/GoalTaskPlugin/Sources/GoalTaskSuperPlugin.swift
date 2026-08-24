import AgentToolKit
import Combine
import KernelCore
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderLifecycleHooks
import ProviderStorage
import ProviderToolManager
import SwiftUI

/// KernelCore implementation of the goal and task workflow.
///
/// It intentionally uses the legacy plugin's storage key and SQLite layout so
/// existing goals remain visible after the host switches to LumiApp2.
@MainActor
public final class GoalTaskSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.goal-task"
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

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            Plugin.logger.error("🎯 Storage service not available")
            return
        }

        // Keep the exact old root key. GoalStateManager appends GoalTaskPlugin
        // itself, matching the legacy goals.sqlite location byte-for-byte.
        Plugin._sharedManager = try GoalStateManager(
            databaseRootURL: storage.pluginDataDirectory(for: "GoalTaskPlugin")
        )

        guard let conversations = kernel.resolveProvider((any ConversationManaging).self) else { return }
        let bridge = GoalTaskConversationBridge(conversations)
        conversationBridge = bridge
        goalVM.updateCurrentConversationID(bridge.selectedConversationID)

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
        hooks.addTurnFinishedHook { context in
            guard context.endReason == .completed else { return }
            await GoalTaskContinuation.handle(conversationID: context.conversationID, agentLoop: agentLoop)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?.removeItem(id: "\(id).active-goal")
        kernel.resolveProvider((any ChatSectionProviding).self)?.removeBarItem(id: "\(id).toolbar-button")
        [CreateGoalV2Tool.toolName, AddTasksToGoalV2Tool.toolName, GetGoalProgressV2Tool.toolName,
         UpdateGoalStatusV2Tool.toolName, UpdateTaskStatusV2Tool.toolName]
            .forEach { kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: $0) }
        conversationBridge = nil
        Plugin._sharedManager = nil
    }
}

@MainActor
private final class GoalTaskConversationBridge: ObservableObject {
    @Published var selectedConversationID: UUID?
    private var cancellable: AnyCancellable?

    init(_ conversations: any ConversationManaging) {
        selectedConversationID = conversations.selectedConversationID
        cancellable = conversations.objectWillChange.sink { [weak self, weak conversations] _ in
            self?.selectedConversationID = conversations?.selectedConversationID
        }
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

private enum GoalTaskContinuation {
    @MainActor
    static func handle(conversationID: UUID, agentLoop: any AgentLoopProviding) async {
        guard let manager = Plugin.currentManager() else { return }
        let conversationId = conversationID.uuidString
        let goals = await manager.fetchGoals(conversationId: conversationId)
        let activeGoals = goals.filter { $0.status == .pending || $0.status == .inProgress }
        guard !activeGoals.isEmpty else {
            if !goals.isEmpty, goals.allSatisfy({ $0.status == .completed || $0.status == .skipped }) {
                try? await manager.deleteAllGoals(conversationId: conversationId)
                postChange(conversationId)
            }
            return
        }
        var hasActiveTasks = false
        for goal in activeGoals {
            let tasks = await manager.fetchTasks(goalId: goal.id)
            if tasks.contains(where: { $0.status == .inProgress || $0.status == .pending }) {
                hasActiveTasks = true
                break
            }
        }
        guard hasActiveTasks else { return }
        guard await manager.incrementContinuationCount(conversationId: conversationId) != nil else {
            for goal in goals where goal.status != .completed && goal.status != .skipped {
                _ = try? await manager.updateGoalStatus(
                    id: goal.id, status: .failed,
                    failureReason: "Automatic continuation limit reached before all tasks were completed."
                )
            }
            postChange(conversationId)
            return
        }
        await manager.markContinuation(conversationId: conversationId)
        // The completed hook runs while the previous runTurn is unwinding.
        // Yield once so the next no-message turn cannot be rejected as concurrent.
        Task { @MainActor in
            await Task.yield()
            _ = try? await agentLoop.runTurn(in: conversationID)
        }
    }

    @MainActor private static func postChange(_ conversationId: String) {
        NotificationCenter.default.post(name: .goalDidChange, object: nil, userInfo: ["conversationId": conversationId])
    }
}
