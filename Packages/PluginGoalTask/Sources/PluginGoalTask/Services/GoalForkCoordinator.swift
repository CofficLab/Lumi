import Foundation
import ProviderConversation
import ProviderMessageSender

/// 「在新对话中继续」的执行器：复制 Goal 到新会话并立即开跑。
///
/// 之所以单独成层而不是塞进 View：这条链路要同时协调三个 Provider
/// （建对话 → 复制 Goal → 发消息启动回合），把它留在 View 里会让视图
/// 承担事务编排，且难以在不跑真实回合的前提下测试。
@MainActor
final class GoalForkCoordinator {
    private let conversations: any ConversationManaging
    private let messageSender: any MessageSendingProviding

    init(conversations: any ConversationManaging, messageSender: any MessageSendingProviding) {
        self.conversations = conversations
        self.messageSender = messageSender
    }

    /// 把 `goal` 复制到一个全新对话，并在该对话里发起第一轮。
    ///
    /// - Throws: 建对话或复制 Goal 失败时抛出，调用方负责呈现错误。
    func forkAndStart(goal: GoalDisplayItem, tasks: [GoalTaskDisplayItem]) async throws {
        guard let manager = Plugin.currentManager() else {
            throw GoalForkError.managerUnavailable
        }

        let conversationID = try conversations.createConversation(
            title: goal.title,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        let conversationId = conversationID.uuidString

        do {
            let forked = try await manager.forkGoal(id: goal.id, into: conversationId)
            GoalChangeCenter.shared.notify(conversationID: conversationID)

            let prompt = Self.resumePrompt(for: forked, tasks: tasks)
            guard let commit = try messageSender.commitUserMessage(prompt, conversationID: conversationID) else {
                throw GoalForkError.emptyPrompt
            }
            await messageSender.startTurn(for: commit)
        } catch {
            // 新建的空对话对用户没有价值，复制失败时回收掉，避免留下孤儿会话。
            conversations.deleteConversation(id: conversationID)
            throw error
        }
    }

    /// 构造恢复回合的开场指令。
    ///
    /// 只陈述事实（目标与未完成任务），**不**下「继续执行」这类指令：
    /// 是否推进由模型基于当前上下文自行判断，用户可能只想在新对话里接着聊。
    private static func resumePrompt(for goal: Goal, tasks: [GoalTaskDisplayItem]) -> String {
        var lines: [String] = ["这个对话延续自另一个对话中的目标："]
        lines.append("")
        lines.append("## Goal [\(goal.id)]: \(goal.title)")

        if let description = goal.goalDescription, !description.isEmpty {
            lines.append(description)
        }
        if let criteria = goal.successCriteria, !criteria.isEmpty {
            lines.append("成功标准：\(criteria)")
        }

        let outstanding = tasks.filter { $0.status == .pending || $0.status == .inProgress }
        if !outstanding.isEmpty {
            lines.append("")
            lines.append("## 未完成的任务")
            for task in outstanding {
                lines.append("- [\(task.id)] \(task.title)（\(task.status.rawValue)）")
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Errors

enum GoalForkError: LocalizedError {
    case managerUnavailable
    case emptyPrompt

    var errorDescription: String? {
        switch self {
        case .managerUnavailable:
            return "Goal data is not ready yet."
        case .emptyPrompt:
            return "Failed to start the new conversation."
        }
    }
}
