import Foundation
import LumiCoreKit

/// Turn 结束后检查未完成任务，并在需要时入队跟进提示。
///
/// `LumiSendMiddleware` 仅覆盖发送前阶段；turn 完成逻辑通过 `lumiTurnCompleted` 通知触发。
@MainActor
enum AutoTaskTurnCheckRuntime {
    private static var observer: NSObjectProtocol?

    static func start(chatServiceProvider: @escaping @MainActor () -> (any LumiChatServicing)?) {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: .lumiTurnCompleted,
            object: nil,
            queue: .main
        ) { notification in
            guard let conversationID = notification.userInfo?[LumiMessageSavedNotification.conversationIDKey] as? UUID else {
                return
            }
            Task { @MainActor in
                await handleTurnCompleted(
                    conversationID: conversationID,
                    chatServiceProvider: chatServiceProvider
                )
            }
        }
    }

    private static func handleTurnCompleted(
        conversationID: UUID,
        chatServiceProvider: @MainActor () -> (any LumiChatServicing)?
    ) async {
        guard let chatService = chatServiceProvider() else {
            return
        }

        let manager = TaskStateManager.shared
        let conversationIdStr = conversationID.uuidString
        let tasks = await manager.fetchTasks(conversationId: conversationIdStr)
        let activeTasks = tasks.filter { $0.status == .inProgress || $0.status == .pending }

        guard !activeTasks.isEmpty else { return }

        let turnMessages = turnMessages(for: conversationID, chatService: chatService)
        let hasUpdateCall = turnMessages.contains { message in
            guard message.role == .assistant, let toolCalls = message.toolCalls else { return false }
            return toolCalls.contains { $0.name == "update_task" }
        }

        guard !hasUpdateCall else { return }

        let prompt = buildTaskCheckPrompt(tasks: activeTasks)
        chatService.enqueueText(prompt, in: conversationID)
    }

    private static func turnMessages(
        for conversationID: UUID,
        chatService: any LumiChatServicing
    ) -> [LumiChatMessage] {
        let messages = chatService.messages(for: conversationID)
        guard let lastUserIndex = messages.lastIndex(where: { $0.role == .user }) else {
            return []
        }
        return Array(messages[(lastUserIndex + 1)...]).filter { $0.role != .status }
    }

    private static func buildTaskCheckPrompt(tasks: [TaskItem]) -> String {
        var lines: [String] = []

        let inProgressTasks = tasks.filter { $0.status == .inProgress }
        let pendingTasks = tasks.filter { $0.status == .pending }

        if !inProgressTasks.isEmpty && !pendingTasks.isEmpty {
            lines.append("以下任务尚未完成，请继续推进：")
            lines.append("")
            lines.append("【进行中】")
            for task in inProgressTasks {
                lines.append("- [\(task.id)] \(task.title)")
            }
            lines.append("")
            lines.append("【待开始】")
            for task in pendingTasks {
                lines.append("- [\(task.id)] \(task.title)")
            }
        } else if !inProgressTasks.isEmpty {
            lines.append("以下任务仍处于进行中状态，请检查它们是否已经完成：")
            lines.append("")
            for task in inProgressTasks {
                lines.append("- [\(task.id)] \(task.title)")
                if let detail = task.detail {
                    lines.append("  详情：\(detail)")
                }
            }
        } else {
            lines.append("以下任务尚未开始，请开始处理：")
            lines.append("")
            for task in pendingTasks {
                lines.append("- [\(task.id)] \(task.title)")
                if let detail = task.detail {
                    lines.append("  详情：\(detail)")
                }
            }
        }

        lines.append("")
        lines.append("如果某个任务已经完成，请调用 `update_task` 将其状态更新为 `completed`。")
        lines.append("如果某个任务需要进行中，请调用 `update_task` 将其状态更新为 `in_progress`。")
        lines.append("如果某个任务仍在进行中，请继续处理。")
        return lines.joined(separator: "\n")
    }
}
