import Foundation
import LumiKernel
import os
import SuperLogKit

/// AskUser 回答后自动恢复 AgentTurn 的观察者
///
/// 监听 `.lumiAskUserDidAnswer` 通知，执行以下操作：
/// 1. 找到 pending 的 ask_user toolCall 所在消息
/// 2. 用真实答案覆盖原 pending result
/// 3. 重新启动 agent turn
///
/// 挂载在 AskUserPlugin.onBoot，由 AskUserBridge 触发。
@MainActor
    public final class AskUserResumeObserver: SuperLog, @unchecked @preconcurrency Sendable {
    public nonisolated static let emoji = "🔄"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.ask-user.resume")

    public static let shared = AskUserResumeObserver()

    private var kernel: LumiKernel?
    private var notificationObserver: NSObjectProtocol?

    private init() {}

    // MARK: - Lifecycle

    /// 启动观察者，注册通知监听
    public func start(kernel: LumiKernel) {
        self.kernel = kernel

        guard notificationObserver == nil else { return }

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .lumiAskUserDidAnswer,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            // Extract simple Sendable values before creating Task to avoid Sendable issues
            let conversationIdStr = notification.userInfo?[LumiAskUserNotification.conversationIDKey] as? String
            let toolCallId = notification.userInfo?[LumiAskUserNotification.toolCallIDKey] as? String
            let answer = notification.userInfo?[LumiAskUserNotification.answerKey] as? String
            Task { @MainActor [conversationIdStr, toolCallId, answer] in
                await self.handleAskUserAnswer(conversationId: conversationIdStr, toolCallId: toolCallId, answer: answer)
            }
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)AskUserResumeObserver started")
        }
    }

    /// 停止观察者，移除通知监听
    public func stop() {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        kernel = nil
    }

    // MARK: - Notification Handling

    private func handleAskUserAnswer(
        conversationId: String?,
        toolCallId: String?,
        answer: String?
    ) async {
        guard let kernel else {
            if Self.verbose {
                Self.logger.error("\(Self.t)kernel is nil, skipping")
            }
            return
        }

        guard let conversationIdStr = conversationId,
              let conversationID = UUID(uuidString: conversationIdStr),
              let toolCallID = toolCallId,
              let rawAnswer = answer
        else {
            if Self.verbose {
                Self.logger.error("\(Self.t)Missing required userInfo fields")
            }
            return
        }

        let trimmedAnswer = rawAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)Empty answer, skipping")
            }
            return
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)收到回答 conversationID=\(conversationIdStr.prefix(8))… toolCallID=\(toolCallID) answer=\(trimmedAnswer)")
        }

        // 步骤 1：找到包含该 toolCallID 的 assistant 消息
        guard let (assistantMessageID, _) = findAssistantMessage(
            toolCallID: toolCallID,
            conversationID: conversationID,
            kernel: kernel
        ) else {
            if Self.verbose {
                Self.logger.error("\(Self.t)找不到 toolCallID=\(toolCallID) 的 assistant 消息")
            }
            return
        }

        // 步骤 2：用真实答案覆盖 pending result
        let updatedResult = LumiToolResult(
            content: trimmedAnswer,
            duration: nil,
            isError: false,
            imageAttachments: []
        )
        kernel.messageManager?.updateToolCallResult(
            updatedResult,
            toolCallID: toolCallID,
            assistantMessageID: assistantMessageID,
            in: conversationID
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已更新 toolCall result，准备重启 turn")
        }

        // 步骤 3：重新启动 agent turn
        if let runner = kernel.agentTurnRunner {
            do {
                let outcome = try await runner.runTurn(in: conversationID)
                if Self.verbose {
                    Self.logger.info("\(Self.t)turn 恢复完成 outcome=\(String(describing: outcome))")
                }
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)turn 恢复失败 error=\(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Helpers

    /// 在消息历史中找到包含指定 toolCallID 的 assistant 消息。
    /// 返回 (assistantMessageID, toolCall)。
    private func findAssistantMessage(
        toolCallID: String,
        conversationID: UUID,
        kernel: LumiKernel
    ) -> (UUID, LumiToolCall)? {
        let messages = kernel.messageManager?.messages(for: conversationID) ?? []

        for message in messages.reversed() {
            guard message.role == .assistant,
                  let toolCalls = message.toolCalls
            else {
                continue
            }

            if let toolCall = toolCalls.first(where: { $0.id == toolCallID }) {
                return (message.id, toolCall)
            }
        }

        return nil
    }
}
