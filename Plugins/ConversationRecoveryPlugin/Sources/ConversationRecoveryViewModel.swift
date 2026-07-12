import Foundation
import LumiChatKit
import LumiCoreKit
import os

/// 对话恢复视图模型
///
/// 从 ConversationRecoveryStateMonitor 获取中断状态，
/// 提供恢复和忽略操作的入口。
@MainActor
public final class ConversationRecoveryViewModel: ObservableObject {
    @Published public var interruption: LumiConversationInterruption?

    private let monitor = ConversationRecoveryStateMonitor.shared
    private var notificationObserver: NSObjectProtocol?

    public init() {}

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// 刷新当前会话的中断状态
    public func refresh(conversationID: UUID?) {
        guard let conversationID else {
            interruption = nil
            return
        }

        // 从监控器获取中断信息
        interruption = monitor.getInterruption(for: conversationID)

        // 注册通知监听，实时更新中断状态
        if notificationObserver == nil {
            notificationObserver = NotificationCenter.default.addObserver(
                forName: .lumiMessageSaved,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let convID = notification.userInfo?[LumiMessageSavedNotification.conversationIDKey] as? UUID,
                       convID == conversationID {
                        self.interruption = self.monitor.getInterruption(for: conversationID)
                    }
                }
            }
        }
    }

    /// 恢复对话
    public func recover() async {
        guard let interruption else { return }

        // 根据中断类型执行不同的恢复策略
        switch interruption.kind {
        case .streamingInterrupted, .errorState, .turnNotCompleted:
            // 重新发送最后一条用户消息
            if let lastUserMessageID = interruption.lastUserMessageID,
               let chatService = ChatService.shared {
                await chatService.resendMessage(id: lastUserMessageID, in: interruption.conversationID)
            }

        case .toolExecutionIncomplete:
            // 清除未完成的工具调用，然后继续 agent turn
            if let chatService = ChatService.shared,
               let incompleteToolCallMessageID = interruption.incompleteToolCallMessageID {
                clearIncompleteToolCalls(
                    assistantMessageID: incompleteToolCallMessageID,
                    conversationID: interruption.conversationID,
                    chatService: chatService
                )
                chatService.continueTurn(in: interruption.conversationID)
            }

        case .awaitingUserResponse:
            // 无需恢复，用户正在等待输入
            break
        }

        // 标记为已恢复
        monitor.markRecovered(conversationID: interruption.conversationID)
        self.interruption = nil
    }

    /// 忽略中断
    public func dismiss() {
        guard let interruption else { return }
        monitor.markRecovered(conversationID: interruption.conversationID)
        self.interruption = nil
    }

    // MARK: - Private Methods

    /// 清除未完成的工具调用结果
    private func clearIncompleteToolCalls(
        assistantMessageID: UUID,
        conversationID: UUID,
        chatService: ChatService
    ) {
        guard let message = chatService.messages(for: conversationID).first(where: { $0.id == assistantMessageID }),
              let toolCalls = message.toolCalls else {
            return
        }

        // 清除没有 result 的 toolCall
        let incompleteToolCallIDs = toolCalls.filter { $0.result == nil }.map(\.id)

        for toolCallID in incompleteToolCallIDs {
            // 将未完成的工具调用标记为错误
            let errorResult = LumiToolResult(
                content: "工具执行被中断（App 崩溃或用户手动停止）。",
                isError: true
            )
            chatService.updateToolCallResult(
                errorResult,
                toolCallID: toolCallID,
                assistantMessageID: assistantMessageID,
                conversationID: conversationID
            )
        }
    }
}
