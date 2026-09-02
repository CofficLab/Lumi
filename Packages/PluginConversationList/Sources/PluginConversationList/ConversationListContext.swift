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
/// 设计为 `ObservableObject` class，使 `selectedConversationID` 等可变状态
/// 可被 SwiftUI 视图通过 `@ObservedObject` 直接观察，无需轮询协议存在类型属性。
@MainActor
final class ConversationListContext: ObservableObject {
    let conversations: any ConversationManaging
    let project: (any ProjectProviding)?
    let agentTurn: (any AgentLoopProviding)?
    let conversationState: (any ConversationStateProviding)?
    let chat: (any ChatSectionProviding)?
    /// 当前选中的对话 ID，由 `addSelectedConversationObserver` 回调同步更新。
    ///
    /// 视图通过 `@ObservedObject` 直接观察此属性，无需间接读取
    /// `conversations.selectedConversationID`（协议存在类型，SwiftUI 难以追踪）。
    @Published var selectedConversationID: UUID?

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

    /// 当前项目路径；`nil` 表示未选中项目。
    var currentProjectPath: String? {
        project?.currentProject?.path
    }

    /// 当前选中的项目名；用于分段标题与 HeaderBar。
    var currentProjectName: String? {
        project?.currentProject?.name ?? currentProjectPath
    }
}
