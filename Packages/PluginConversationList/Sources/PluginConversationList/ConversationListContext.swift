import Foundation
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderProject

/// 新版插件上下文：聚合复刻旧版 ConversationListPlugin 所需的所有内核能力。
///
/// 视图通过它访问对话管理 / 项目 / Agent 回合 / Chat 分区，
/// 避免视图直接依赖 KernelCoreContainer 或 KernelLumi。
@MainActor
struct ConversationListContext {
    let conversations: any ConversationManaging
    let project: (any ProjectProviding)?
    let agentTurn: (any AgentLoopProviding)?
    let chat: (any ChatSectionProviding)?

    /// 当前项目路径；`nil` 表示未选中项目。
    var currentProjectPath: String? {
        project?.currentProject?.path
    }

    /// 当前选中的项目名；用于分段标题与 HeaderBar。
    var currentProjectName: String? {
        project?.currentProject?.name ?? currentProjectPath
    }
}
