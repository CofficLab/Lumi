import Foundation
import ProviderConversation
import ProviderMessageSender

/// 「在新对话中继续」需要的最小能力边界。
///
/// 事务编排（建对话 → 复制 Goal → 发消息启动回合）只依赖下面五个操作，
/// 不直接持有 `ConversationManaging` / `MessageSendingProviding` 宽接口。
@MainActor
protocol GoalForkCapability: AnyObject {
    /// 新建一个对话并返回其 ID。
    @discardableResult
    func createConversation(title: String) throws -> UUID

    /// 回收复制失败留下的空对话。
    func discardConversation(id: UUID)

    /// 把 Goal 复制到目标对话，返回复制后的 Goal。
    func forkGoal(id: String, into conversationID: UUID) async throws -> Goal

    /// 以指定对话 ID 提交一条用户消息；空内容时返回 `nil`。
    func commitUserMessage(_ text: String, conversationID: UUID) throws -> MessageSendCommit?

    /// 启动指定提交对应的回合。
    func startTurn(for commit: MessageSendCommit) async
}

/// 将内核的会话管理与消息发送能力收窄为「Goal 分叉」所需的能力。
@MainActor
final class GoalForkCapabilityAdapter: GoalForkCapability {
    private let conversations: any ConversationManaging
    private let messageSender: any MessageSendingProviding

    init(
        conversations: any ConversationManaging,
        messageSender: any MessageSendingProviding
    ) {
        self.conversations = conversations
        self.messageSender = messageSender
    }

    @discardableResult
    func createConversation(title: String) throws -> UUID {
        try conversations.createConversation(
            title: title,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
    }

    func discardConversation(id: UUID) {
        conversations.deleteConversation(id: id)
    }

    func forkGoal(id: String, into conversationID: UUID) async throws -> Goal {
        guard let manager = Plugin.currentManager() else {
            throw GoalForkError.managerUnavailable
        }
        return try await manager.forkGoal(id: id, into: conversationID.uuidString)
    }

    func commitUserMessage(_ text: String, conversationID: UUID) throws -> MessageSendCommit? {
        try messageSender.commitUserMessage(text, conversationID: conversationID)
    }

    func startTurn(for commit: MessageSendCommit) async {
        await messageSender.startTurn(for: commit)
    }
}
