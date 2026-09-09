import Foundation
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
import ProviderProject

/// 新版插件上下文：聚合复刻旧版 ConversationListPlugin 所需的所有内核能力。
///
/// 视图通过它访问对话管理 / 项目 / Agent 回合 / Chat 分区，
/// 避免视图直接依赖 KernelCoreContainer 或 KernelLumi。
///
@MainActor
final class ConversationListContext {
    enum Event {
        case selectedConversationChanged(UUID?)
        case conversationsChanged
    }

    protocol ObserverHandle: AnyObject {
        func cancel()
    }

    private final class Handle: ObserverHandle {
        private let cancelAction: () -> Void
        private var isCancelled = false

        init(cancelAction: @escaping () -> Void) {
            self.cancelAction = cancelAction
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            cancelAction()
        }
    }

    let conversations: any ConversationManaging
    let project: (any ProjectProviding)?
    let agentTurn: (any AgentLoopProviding)?
    let conversationState: (any ConversationStateProviding)?
    let chat: (any ChatSectionProviding)?
    /// 当前选中的对话 ID，由 `ConversationListContextObserver` 同步更新。
    private(set) var selectedConversationID: UUID?
    private var observers: [UUID: (Event) -> Void] = [:]

    init(
        conversations: any ConversationManaging,
        project: (any ProjectProviding)?,
        agentTurn: (any AgentLoopProviding)?,
        conversationState: (any ConversationStateProviding)?,
        chat: (any ChatSectionProviding)?
    ) {
        self.conversations = conversations
        self.project = project
        self.agentTurn = agentTurn
        self.conversationState = conversationState
        self.chat = chat
        self.selectedConversationID = conversations.selectedConversationID
    }

    @discardableResult
    func addObserver(_ callback: @escaping (Event) -> Void) -> any ObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    /// 当前项目路径；`nil` 表示未选中项目。
    var currentProjectPath: String? {
        project?.currentProject?.path
    }

    /// 当前选中的项目名；用于分段标题与 HeaderBar。
    var currentProjectName: String? {
        project?.currentProject?.name ?? currentProjectPath
    }

    func markConversationsChanged() {
        notify(.conversationsChanged)
    }

    func setSelectedConversationID(_ id: UUID?) {
        guard selectedConversationID != id else { return }
        selectedConversationID = id
        notify(.selectedConversationChanged(id))
    }

    private func notify(_ event: Event) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}
