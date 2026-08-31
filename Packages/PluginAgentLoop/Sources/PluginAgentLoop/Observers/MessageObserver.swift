import Foundation
import KitSuperLog
import os
import ProviderAgentLoop
import ProviderMessage

/// 消费用户消息插入事件，并启动对应的 AgentLoop 回合。
@MainActor
final class MessageObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.agent-loop.message-observer"
    )
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose = false

    private weak var agentLoop: (any AgentLoopProviding)?
    private let messages: any MessageManaging
    private var messageObserver: (any MessageInsertedObserverHandle)?

    init(messages: any MessageManaging, agentLoop: any AgentLoopProviding) {
        self.messages = messages
        self.agentLoop = agentLoop
        self.messageObserver = messages.addMessageInsertedObserver { [weak self] message, conversationID in
            self?.handle(message: message, conversationID: conversationID)
        }
    }

    func cancel() {
        messageObserver?.cancel()
        messageObserver = nil
    }

    private func handle(message: Message, conversationID: UUID) {
        guard message.role == .user else { return }
        guard agentLoop != nil else {
            Self.logger.error("\(Self.emoji)无法处理用户消息事件：AgentLoopProvider 已释放")
            return
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)🍋 message event starts turn conversation=\(conversationID.uuidString.prefix(8))")
        }

        Task { @MainActor [weak self] in
            guard let self, let agentLoop = self.agentLoop else {
                Self.logger.error("\(Self.emoji)无法启动用户消息回合：AgentLoopProvider 已释放")
                return
            }

            // ask_user 是可被用户主动跳过的交互：用户继续输入新消息时，
            // 不应让这条消息卡在一个永远不会被启动的独立回合里。把挂起点
            // 以“跳过”结果恢复，当前消息会保留在历史中并由恢复后的 LLM
            // 请求继续处理；这不是把当前消息当作 ask_user 的答案。
            if let suspension = self.askUserSuspension(
                in: conversationID,
                agentLoop: agentLoop
            ) {
                do {
                    _ = try await agentLoop.resumeTurn(
                        in: conversationID,
                        request: AgentTurnResumeRequest(
                            suspensionID: suspension.suspensionID,
                            answer: Self.skippedAskUserAnswer
                        )
                    )
                } catch {
                    Self.logger.error("\(Self.emoji)跳过 ask_user 挂起点失败：\(error.localizedDescription)")
                }
                return
            }

            guard !agentLoop.isRunning(for: conversationID) else { return }
            do {
                _ = try await agentLoop.runTurn(in: conversationID)
            } catch {
                Self.logger.error("\(Self.emoji)event-driven turn failed: \(error.localizedDescription)")
            }
        }
    }

    private static let skippedAskUserAnswer =
        "The user continued the conversation without answering the previous ask_user question. Treat that question as skipped and respond to the latest user message."

    private func askUserSuspension(
        in conversationID: UUID,
        agentLoop: any AgentLoopProviding
    ) -> AgentLoopSuspension? {
        guard agentLoop.state(for: conversationID) == .suspended,
              let suspension = agentLoop.suspension(for: conversationID),
              let toolCallID = suspension.toolCallID,
              let assistantMessage = messages.messages(for: conversationID).reversed().first(where: {
                  $0.role == .assistant
                      && $0.toolCalls?.contains(where: { $0.id == toolCallID }) == true
              }),
              let toolCall = assistantMessage.toolCalls?.first(where: { $0.id == toolCallID }),
              toolCall.name == "ask_user",
              toolCall.result?.awaitingUserResponse == true else {
            return nil
        }
        return suspension
    }
}
