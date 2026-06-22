import Foundation
import LumiCoreKit

/// Turn 结束后检查未完成任务，并在需要时入队跟进提示。
///
/// 仅响应 `lumiTurnFinished` 且 `reason == .completed` 的事件；
/// 供应商故障等失败 Turn 由 `LumiChatKit` 标记为 `.failed`，不会触发自动续聊。
@MainActor
enum AutoTaskTurnCheckRuntime {
    private static var observer: NSObjectProtocol?

    static func start(chatServiceProvider: @escaping @MainActor () -> (any LumiChatServicing)?) {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: .lumiTurnFinished,
            object: nil,
            queue: .main
        ) { notification in
            guard let conversationID = notification.userInfo?[LumiMessageSavedNotification.conversationIDKey] as? UUID else {
                return
            }
            guard let reason = LumiTurnEndReason(notificationUserInfo: notification.userInfo),
                  reason.allowsAutomaticContinuation
            else {
                return
            }
            Task { @MainActor in
                await handleSuccessfulTurnCompleted(
                    conversationID: conversationID,
                    chatServiceProvider: chatServiceProvider
                )
            }
        }
    }

    private static func handleSuccessfulTurnCompleted(
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

        let messages = chatService.messages(for: conversationID)
        let turnMessages = LumiAgentTurnDerivation.turnMessagesSinceLastUser(in: messages)
        guard !LumiAgentTurnDerivation.assistantCalledTool(named: "update_task", in: turnMessages) else {
            return
        }

        let prompt = buildTaskCheckPrompt(tasks: activeTasks)
        chatService.enqueueText(prompt, in: conversationID)
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
