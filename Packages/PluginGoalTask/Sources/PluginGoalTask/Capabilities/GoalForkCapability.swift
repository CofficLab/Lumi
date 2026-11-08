import Foundation
import ProviderConversation
import ProviderMessageSender

/// Goal 复制结果：新 Goal 与其任务副本（任务副本使用新的 ID）。
@MainActor
struct ForkedGoal {
    let goal: Goal
    let tasks: [GoalTask]
}

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

    /// 把 Goal 复制到目标对话，返回复制后的 Goal 及其任务副本。
    func forkGoal(id: String, into conversationID: UUID) async throws -> ForkedGoal

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

    func forkGoal(id: String, into conversationID: UUID) async throws -> ForkedGoal {
        guard let manager = Plugin.currentManager() else {
            throw GoalForkError.managerUnavailable
        }
        return try await manager.forkGoal(id: id, into: conversationID.uuidString)
    }

    func commitUserMessage(_ text: String, conversationID: UUID) throws -> MessageSendCommit? {
        // 必须走显式附件重载并传空数组：便捷重载会消费发送器全局挂起的
        // 图片/文件附件，把这些本应随用户下一条消息发出的附件偷走。
        try messageSender.commitUserMessage(
            text,
            imageAttachments: [],
            fileAttachments: [],
            conversationID: conversationID
        )
    }

    func startTurn(for commit: MessageSendCommit) async {
        await messageSender.startTurn(for: commit)
    }
}
