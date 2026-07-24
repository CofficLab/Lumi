import Foundation
import LumiKernel
import os

/// 监听用户对 `ask_user` 的回答，回写 tool result 并恢复 Agent 循环。
///
/// 数据流：
/// ```
/// 用户点击选项 → AskUserBridge.resume(...) 发送 .lumiAskUserDidAnswer
///     ↓
/// AskUserAnswerObserver 收到通知
///     ↓
/// 把 pending 的 tool result 消息（__ASK_USER_PENDING__...）替换成真实答案
///     ↓
/// kernel.agentTurnRunner?.runTurn(in:) 恢复 Agent 循环
/// ```
///
/// 由 `AskUserPlugin.onBoot` 实例化并持有，生命周期与插件一致。
@MainActor
final class AskUserAnswerObserver {
    private weak var kernel: LumiKernel?
    private var observerToken: NSObjectProtocol?

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.ask-user.observer")

    init(kernel: LumiKernel) {
        self.kernel = kernel
        self.observerToken = NotificationCenter.default.addObserver(
            forName: .lumiAskUserDidAnswer,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // 先在回调线程提取 Sendable 字段（String），避免跨 Task 传递非 Sendable 的 Notification
            let userInfo = notification.userInfo ?? [:]
            let conversationIDString = userInfo[LumiAskUserNotification.conversationIDKey] as? String
            let toolCallID = userInfo[LumiAskUserNotification.toolCallIDKey] as? String
            let answer = userInfo[LumiAskUserNotification.answerKey] as? String

            Task { @MainActor in
                self?.handle(
                    conversationIDString: conversationIDString,
                    toolCallID: toolCallID,
                    answer: answer
                )
            }
        }
    }

    deinit {
        // observerToken 非 Sendable，整个访问需在主演员上完成。
        MainActor.assumeIsolated {
            if let token = observerToken {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }

    private func handle(
        conversationIDString: String?,
        toolCallID: String?,
        answer: String?
    ) {
        guard let conversationIDString,
              let conversationID = UUID(uuidString: conversationIDString),
              let toolCallID,
              let answer
        else {
            Self.logger.error("收到 .lumiAskUserDidAnswer 但 userInfo 缺字段，已忽略")
            return
        }

        guard let kernel else {
            Self.logger.error("kernel 已释放，无法回写答案")
            return
        }

        rewritePendingToolResult(
            conversationID: conversationID,
            toolCallID: toolCallID,
            answer: answer,
            kernel: kernel
        )

        resumeTurn(conversationID: conversationID, kernel: kernel)
    }

    /// 把 pending 的 `.tool` 消息 content 替换为用户真实答案。
    ///
    /// AgentTurnRunner 执行 ask_user 时会把 `__ASK_USER_PENDING__\n{json}` 作为一条
    /// `role == .tool`、`toolCallID` 指向该 toolCall 的消息插入历史。
    /// 恢复 turn 前必须把它换成真实答案，否则 LLM 下一轮看到的仍是占位符。
    private func rewritePendingToolResult(
        conversationID: UUID,
        toolCallID: String,
        answer: String,
        kernel: LumiKernel
    ) {
        guard let messageManager = kernel.messageManager else {
            Self.logger.error("messageManager 不可用，无法回写答案")
            return
        }

        let messages = messageManager.messages(for: conversationID)
        guard let pending = messages.first(where: { $0.role == .tool && $0.toolCallID == toolCallID }) else {
            Self.logger.error("未找到 toolCallID=\(toolCallID) 的 pending tool 消息")
            return
        }

        messageManager.updateMessage(id: pending.id, in: conversationID, content: answer)
        Self.logger.info("已回写答案到 toolCallID=\(toolCallID.prefix(8))")
    }

    /// 恢复 Agent 循环。
    ///
    /// turn 暂停时（`.awaitingUserResponse`）其 task 已结束并从 `activeTurnTasks` 移除，
    /// 因此可以直接再次 `runTurn` 启动新一轮循环。
    private func resumeTurn(conversationID: UUID, kernel: LumiKernel) {
        guard let turnRunner = kernel.agentTurnRunner else {
            Self.logger.error("agentTurnRunner 不可用，无法恢复 turn")
            return
        }

        Task { [weak turnRunner] in
            do {
                let outcome = try await turnRunner?.runTurn(in: conversationID)
                Self.logger.info("turn 恢复完成，outcome=\(String(describing: outcome))")
            } catch {
                Self.logger.error("恢复 turn 失败: \(error.localizedDescription)")
            }
        }
    }
}
