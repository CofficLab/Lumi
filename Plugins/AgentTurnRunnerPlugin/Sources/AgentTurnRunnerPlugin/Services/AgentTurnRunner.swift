import Foundation
import LumiKernel
import os
import SuperLogKit

/// Implementation of `AgentTurnRunning` that executes a full agent turn.
///
/// The agent turn loop:
/// 1. Send messages to LLM
/// 2. Receive response (possibly with tool calls)
/// 3. For each tool call:
///    a. Check risk level → request user permission if needed
///    b. Execute the tool
///    c. Append tool result message to conversation
/// 4. Repeat until LLM produces final response (no tool calls)
/// 5. Append final assistant message and return outcome
///
/// Sends notifications:
/// - `.lumiMessageSaved` after each message is persisted
/// - `.lumiTurnCompleted` when turn ends normally (completed)
/// - `.lumiTurnFinished` when turn ends (any reason)
@MainActor
public final class AgentTurnRunner: AgentTurnRunning, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-turn-runner")
    public nonisolated static let emoji = "🤖"
    nonisolated static let verbose = true

    // MARK: - Properties

    private weak var kernel: LumiKernel?
    private var activeTurnTasks: [UUID: Task<Void, Never>] = [:]
    private var cancelledConversations: Set<UUID> = []

    // MARK: - Initialization

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)AgentTurnRunnerService")
        }
    }

    // MARK: - AgentTurnRunning

    public func runTurn(in conversationID: UUID) async throws -> AgentTurnOutcome {
        if Self.verbose {
            Self.logger.info("\(Self.t)runTurn 开始 ➡️ conversationID=\(conversationID.uuidString.prefix(8))…")
        }

        // Guard against concurrent turns for the same conversation
        guard activeTurnTasks[conversationID] == nil else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)runTurn 跳过，conversation 已存在活跃 turn")
            }
            return .cancelled
        }

        // Clear cancellation flag for this conversation
        cancelledConversations.remove(conversationID)

        let task = Task { [weak self] in
            guard let self else { return }
            await self.executeTurnLoop(conversationID: conversationID)
        }
        activeTurnTasks[conversationID] = task

        // Wait for turn to complete
        await task.value
        activeTurnTasks.removeValue(forKey: conversationID)

        if Self.verbose {
            Self.logger.info("\(Self.t)runTurn 结束 ➡️ conversationID=\(conversationID.uuidString.prefix(8))…")
        }

        // Determine outcome based on cancellation state
        if cancelledConversations.contains(conversationID) {
            cancelledConversations.remove(conversationID)
            postTurnFinishedNotification(conversationID: conversationID, reason: .cancelled)
            return .cancelled
        }

        postTurnCompletedNotification(conversationID: conversationID)
        return .completed
    }

    public func cancelTurn(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)cancelTurn ➡️ conversationID=\(conversationID.uuidString.prefix(8))…")
        }

        cancelledConversations.insert(conversationID)
        activeTurnTasks[conversationID]?.cancel()
        activeTurnTasks.removeValue(forKey: conversationID)
    }

    public func isRunning(for conversationID: UUID) -> Bool {
        activeTurnTasks[conversationID] != nil
    }

    // MARK: - Turn Loop

    private func executeTurnLoop(conversationID: UUID) async {
        while !cancelledConversations.contains(conversationID) {
            try? Task.checkCancellation()

            guard let kernel else {
                if Self.verbose {
                    Self.logger.error("\(Self.t)kernel 为 nil，turn 结束")
                }
                return
            }

            if Self.verbose {
                Self.logger.info("\(Self.t)开始 LLM 调用...")
            }

            // Build request with current message history
            let history = kernel.messageManager?.messages(for: conversationID) ?? []
            let tools = kernel.toolManager?.allAgentTools() ?? []

            guard let provider = kernel.llmProvider?.allLLMProviders().first else {
                if Self.verbose {
                    Self.logger.error("\(Self.t)没有可用的 LLM Provider")
                }
                appendErrorMessage(conversationID: conversationID, content: "No LLM provider available")
                return
            }

            let model = kernel.llmProvider?.selectedModel ?? type(of: provider).info.defaultModel
            let request = LumiLLMRequest(messages: history, model: model, tools: tools)

            // Call LLM
            let assistantMessage: LumiChatMessage
            do {
                assistantMessage = try await kernel.llmProvider!.sendToSelectedProvider(request)
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)LLM 调用失败: \(error.localizedDescription)")
                }
                appendErrorMessage(conversationID: conversationID, content: error.localizedDescription)
                return
            }

            // Append assistant message to history
            kernel.messageManager?.insertMessage(assistantMessage, to: conversationID)
            postMessageSavedNotification(message: assistantMessage, conversationID: conversationID)

            if Self.verbose {
                Self.logger.info("\(Self.t)收到 assistant 消息, toolCalls=\(assistantMessage.toolCalls?.count ?? 0)")
            }

            // No tool calls → turn complete
            guard let toolCalls = assistantMessage.toolCalls, !toolCalls.isEmpty else {
                if Self.verbose {
                    Self.logger.info("\(Self.t)无 toolCalls，turn 结束")
                }
                return
            }

            // Execute each tool call
            for toolCall in toolCalls {
                try? Task.checkCancellation()

                if cancelledConversations.contains(conversationID) {
                    return
                }

                if Self.verbose {
                    Self.logger.info("\(Self.t)执行工具: \(toolCall.name)")
                }

                // Execute tool
                guard let toolManager = kernel.toolManager else {
                    if Self.verbose {
                        Self.logger.error("\(Self.t)ToolManager 不可用")
                    }
                    // Append error result
                    let errorResult = LumiChatMessage(
                        conversationID: conversationID,
                        role: .tool,
                        content: "Tool service not available",
                        toolCallID: toolCall.id
                    )
                    kernel.messageManager?.insertMessage(errorResult, to: conversationID)
                    postMessageSavedNotification(message: errorResult, conversationID: conversationID)
                    continue
                }

                let result = await toolManager.execute(toolCall, conversationID: conversationID)

                // Update the assistant message's toolCall with the result
                // This allows the UI to show correct visual state (success/failure/duration)
                kernel.messageManager?.updateToolCallResult(
                    result,
                    toolCallID: toolCall.id,
                    assistantMessageID: assistantMessage.id,
                    in: conversationID
                )

                // Append tool result as a special message
                let toolResultMessage = LumiChatMessage(
                    conversationID: conversationID,
                    role: .tool,
                    content: result.content,
                    toolCallID: toolCall.id
                )
                kernel.messageManager?.insertMessage(toolResultMessage, to: conversationID)
                postMessageSavedNotification(message: toolResultMessage, conversationID: conversationID)

                if Self.verbose {
                    Self.logger.info("\(Self.t)工具执行完成: \(toolCall.name), isError=\(result.isError)")
                }
            }

            // Continue loop with new tool results in message history
        }
    }

    // MARK: - Notifications

    private func postMessageSavedNotification(message: LumiChatMessage, conversationID: UUID) {
        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            "messageID": message.id,
            LumiMessageSavedNotification.roleKey: message.role.rawValue,
        ]
        NotificationCenter.default.post(
            name: .lumiMessageSaved,
            object: nil,
            userInfo: userInfo
        )
    }

    private func postTurnCompletedNotification(conversationID: UUID) {
        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiTurnFinishedNotification.reasonKey: LumiTurnEndReason.completed.rawValue,
        ]
        NotificationCenter.default.post(
            name: .lumiTurnCompleted,
            object: nil,
            userInfo: userInfo
        )
        NotificationCenter.default.post(
            name: .lumiTurnFinished,
            object: nil,
            userInfo: userInfo
        )
    }

    private func postTurnFinishedNotification(conversationID: UUID, reason: LumiTurnEndReason) {
        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiTurnFinishedNotification.reasonKey: reason.rawValue,
        ]
        NotificationCenter.default.post(
            name: .lumiTurnFinished,
            object: nil,
            userInfo: userInfo
        )
    }

    // MARK: - Helpers

    private func appendErrorMessage(conversationID: UUID, content: String) {
        guard let kernel else { return }
        let errorMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: content
        )
        kernel.messageManager?.insertMessage(errorMessage, to: conversationID)
        postMessageSavedNotification(message: errorMessage, conversationID: conversationID)
    }
}
