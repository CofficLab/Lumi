import os
import KernelCore
import KitSuperLog
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
import ProviderProject
import ProviderRailView
import ProviderRootView
import ProviderToolbar
import ProviderToolManager
import SwiftUI

/// 对话列表插件。
@MainActor
public final class ConversationListPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-list", category: "ConversationList")

    public let id = "com.coffic.lumi.plugin.conversation-list"
    public let order = 81
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-list",
        name: "Conversation List",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .required
    )


    public init() {}

    /// 关注点存储：回合结束时未选中对话被标记。
    public let attentionStore = ConversationAttentionStore()
    /// 粘性排序稳定器：防止高频消息导致列表跳动。
    public let sortStabilizer = ConversationSortStabilizer()

    private var context: ConversationListContext?
    private var railTabController: ConversationRailTabController?
    /// `addSelectedConversationObserver` 令牌：持有期间持续接收选中变化通知，
    /// 回调同步写入 `context.selectedConversationID`，使视图可观察。
    private var selectedObserverToken: (any SelectedConversationObserverHandle)?
    /// 复刻旧版 onTurnFinished：轮询 AgentTurn 状态迁移（running → 非 running）。
    private var attentionMonitorTask: Task<Void, Never>?
    private var runningConversationIDs: Set<UUID> = []

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ConversationManaging, ChatSectionProviding from kernel")
            return
        }
        let rail = kernel.resolveProvider((any RailViewProviding).self)
        let root = kernel.resolveProvider((any RootViewProviding).self)
        let project = kernel.resolveProvider((any ProjectProviding).self)
        let agentTurn = kernel.resolveProvider((any AgentLoopProviding).self)
        let conversationState = kernel.resolveProvider((any ConversationStateProviding).self)

        let context = ConversationListContext(
            conversations: conversations,
            project: project,
            agentTurn: agentTurn,
            conversationState: conversationState,
            chat: chat
        )
        self.context = context

        // 0. 选中对话观察：回调同步写入 context.selectedConversationID，
        //    视图通过 @ObservedObject 直接观察，无需间接订阅 objectWillChange。
        selectedObserverToken = conversations.addSelectedConversationObserver { [weak context] newID in
            context?.selectedConversationID = newID
        }

        // 1. Rail 侧栏：chats / project-chats 动态注册。
        let railGroupID = "com.coffic.lumi.plugin.chat-panel"
        let controller = ConversationRailTabController(
            context: context,
            attentionStore: attentionStore,
            sortStabilizer: sortStabilizer,
            order: order,
            groupID: railGroupID,
            pluginID: id
        )
        controller.start(rail: rail, root: root)
        railTabController = controller

        // 2. 全局标题栏按钮 + popover（复刻旧版 titleToolbarItems / .trailing）。
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        toolbar?.addToolbarItems([
            ToolbarItem(
                id: "\(id).conversation-list",
                title: LumiPluginLocalization.string("Chats", bundle: .module),
                placement: .trailing,
                order: 200
            ) { [self] in
                ToolbarButton(
                    context: context,
                    attentionStore: attentionStore,
                    sortStabilizer: sortStabilizer
                )
            },
        ])

        // 3. Agent 工具。
        kernel.resolveProvider((any ToolManagerProviding).self)?.add(
            GetRecentConversationsTool(conversations: conversations, project: project),
            pluginID: id
        )
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        guard let context else { return }

        // 4. 回合结束 attention 监听：
        //    轮询 AgentTurn 状态，检测 running → 非 running 的边缘，
        //    结束时若对话未选中则标记关注，选中则标记已读。
        attentionMonitorTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                self.scanAttention(context: context)
            }
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        selectedObserverToken?.cancel()
        selectedObserverToken = nil

        attentionMonitorTask?.cancel()
        attentionMonitorTask = nil
        runningConversationIDs.removeAll()

        railTabController?.stop()
        railTabController = nil

        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(
            ids: ["\(id).conversation-list"]
        )
        kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: "get_recent_conversations")
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(
            ids: ["\(id).chats", "\(id).project-chats"]
        )
    }

    // MARK: - Attention Scan

    /// 扫描一次回合状态：把从 running 变为非 running 的对话视为「回合结束」。
    private func scanAttention(context: ConversationListContext) {
        guard let agentTurn = context.agentTurn else { return }

        let currentIDs = Set(context.conversations.sortedConversations.map(\.id))
        var stillRunning: Set<UUID> = []
        var finished: Set<UUID> = []

        for conversation in context.conversations.sortedConversations {
            if agentTurn.isRunning(for: conversation.id) {
                stillRunning.insert(conversation.id)
            } else if runningConversationIDs.contains(conversation.id) {
                finished.insert(conversation.id)
            }
        }

        // 只保留仍存在的对话，避免已删除对话的 ID 残留。
        runningConversationIDs = stillRunning.intersection(currentIDs)

        for id in finished where currentIDs.contains(id) {
            if context.selectedConversationID == id {
                attentionStore.markRead(conversationID: id)
            } else {
                attentionStore.markNeedsAttention(conversationID: id)
            }
        }
    }
}
