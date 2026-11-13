import Foundation
import ProviderConversation

/// 子代理会话创建失败的原因。
public enum SubagentConversationError: Error, Equatable {
    /// 父会话不存在（可能已被删除）。
    case parentConversationNotFound(UUID)
}

/// 为子代理委托创建隐藏的子会话。
///
/// 子会话以 `parentConversationID` 标记归属：不进入会话列表缓存、不改变
/// 当前选中会话、不发布 `.created` 事件；删除父会话时由会话管理器连带
/// 清理（回合取消、消息清空、工具记录删除、落库删除）。
@MainActor
public final class SubagentConversationBridge {
    private let conversations: any ConversationManaging

    public init(conversations: any ConversationManaging) {
        self.conversations = conversations
    }

    /// 创建继承父会话项目绑定、模型与自动化等级的子会话，等待落库后返回 ID。
    public func createChildConversation(parentID: UUID, description: String) async throws -> UUID {
        guard let parent = await conversations.fetchConversation(id: parentID) else {
            throw SubagentConversationError.parentConversationNotFound(parentID)
        }

        let childID = try await conversations.createConversationAndWait(
            title: description,
            binding: parent.projectPath.map(ProjectBinding.project) ?? .none,
            modelID: parent.modelID,
            parentConversationID: parentID
        )
        conversations.setAutomationLevel(conversations.automationLevel(for: parentID), for: childID)
        return childID
    }
}