import Foundation
import ProviderConversation

/// 新建会话所需的最小会话管理能力。
///
/// 收窄 `ConversationManaging`，聚合本插件三处消费点：
/// - 工具栏「新建会话」按钮：取消选择当前会话；
/// - `create_new_conversation` 工具：创建顶层对话并恢复原选中态；
/// - 建议卡片按钮：切换到指定对话。
@MainActor
protocol NewChatCapability: AnyObject {
    /// 取消当前会话选择（会话面板会按需展示新建会话入口）。
    func deselectConversation()

    /// 当前选中的对话 ID；nil 表示尚未创建任何对话。
    var selectedConversationID: UUID? { get }

    /// 当前选中对话绑定的全局唯一模型 ID。
    var currentModelID: String? { get }

    /// 当前选中对话绑定的项目路径。
    var currentProjectPath: String? { get }

    /// 创建一个顶层对话（会进入侧边栏列表）。
    func createTopLevelConversation(
        title: String?,
        projectPath: String?,
        modelID: String?
    ) throws -> UUID

    /// 切换到指定对话。
    func selectConversation(id: UUID)

    /// 将选中态恢复为 `conversationID`。nil 视为无操作。
    func restoreSelection(to conversationID: UUID?)
}

/// 将 Kernel 的 ConversationManaging Provider 适配为插件能力。
@MainActor
final class NewChatCapabilityAdapter: NewChatCapability {
    private weak var conversations: (any ConversationManaging)?

    init(conversations: (any ConversationManaging)?) {
        self.conversations = conversations
    }

    func deselectConversation() {
        conversations?.deselectConversation()
    }

    var selectedConversationID: UUID? { conversations?.selectedConversationID }

    var currentModelID: String? { conversations?.modelID(for: selectedConversationID) }

    var currentProjectPath: String? {
        guard let id = selectedConversationID else { return nil }
        return conversations?.conversations.first { $0.id == id }?.projectPath
    }

    /// 创建顶层对话：显式传 `parentConversationID: nil`。
    ///
    /// 不能改用子对话来规避选中态抢占——子对话不会进入侧边栏列表
    /// （`fetchConversationPage(includingChildConversations: false)` 会过滤掉），
    /// 用户点击后也找不到它。顶层对话在列表里可见，代价是会抢占
    /// `selectedConversationID`，该行为由工具在同一调用内恢复
    /// （见 `CreateNewConversationTool`）。
    func createTopLevelConversation(
        title: String?,
        projectPath: String?,
        modelID: String?
    ) throws -> UUID {
        guard let conversations else {
            throw NewChatCapabilityError.providerUnavailable
        }
        return try conversations.createConversation(
            title: title,
            projectPath: projectPath,
            modelID: modelID,
            parentConversationID: nil
        )
    }

    func selectConversation(id: UUID) {
        conversations?.selectConversation(id: id)
    }

    func restoreSelection(to conversationID: UUID?) {
        guard let conversationID else { return }
        conversations?.selectConversation(id: conversationID)
    }
}

/// 能力层在 Provider 缺失时的失败原因。
enum NewChatCapabilityError: Error {
    /// `ConversationManaging` 尚未注册。
    case providerUnavailable
}
