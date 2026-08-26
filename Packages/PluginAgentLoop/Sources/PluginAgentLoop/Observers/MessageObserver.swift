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
    private var messageObserver: (any MessageInsertedObserverHandle)?

    init(messages: any MessageManaging, agentLoop: any AgentLoopProviding) {
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
            guard !agentLoop.isRunning(for: conversationID) else { return }
            do {
                _ = try await agentLoop.runTurn(in: conversationID)
            } catch {
                Self.logger.error("\(Self.emoji)event-driven turn failed: \(error.localizedDescription)")
            }
        }
    }
}
