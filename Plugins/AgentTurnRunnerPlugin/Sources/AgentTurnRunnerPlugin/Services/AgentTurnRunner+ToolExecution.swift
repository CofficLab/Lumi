import Foundation
import LumiKernel
import os
import SuperLogKit

// MARK: - Tool Execution

extension AgentTurnRunner {

    /// Finds the latest assistant tool-call message that still has an
    /// unexecuted call. Tool results are no longer embedded in the assistant
    /// message, so the durable completion marker is the separate `.tool`
    /// message with the matching `toolCallID`.
    func incompleteToolCallMessage(in conversationID: UUID) -> LumiChatMessage? {
        let messages = kernel?.messageManager?.messages(for: conversationID) ?? []
        let completedToolCallIDs = Set(
            messages.compactMap { message in
                message.role == .tool ? message.toolCallID : nil
            }
        )
        return messages.reversed().first { message in
            message.role == .assistant
                && message.toolCalls?.contains(where: {
                    $0.result == nil && !completedToolCallIDs.contains($0.id)
                }) == true
        }
    }

    func latestAssistantToolCalls(in conversationID: UUID) -> [LumiToolCall]? {
        let messages = kernel?.messageManager?.messages(for: conversationID) ?? []
        return messages.reversed()
            .first(where: { $0.role == .assistant && !($0.toolCalls ?? []).isEmpty })?
            .toolCalls
    }

    /// Continues an interrupted assistant tool-call batch in order. This path
    /// is used after resuming a suspended call, so already completed calls are
    /// skipped and the next queued call can suspend independently.
    ///
    /// - Returns: `true` when the batch suspended again for user input.
    func executePendingToolCalls(
        in assistantMessage: LumiChatMessage,
        conversationID: UUID
    ) async -> Bool {
        guard let kernel,
              let toolManager = kernel.toolManager,
              let toolCalls = assistantMessage.toolCalls
        else {
            Self.logger.error("\(Self.t)ToolManager 不可用，无法继续工具批次")
            failedConversations.insert(conversationID)
            return false
        }

        var completedToolCallIDs = Set(
            (kernel.messageManager?.messages(for: conversationID) ?? []).compactMap { message in
                message.role == .tool ? message.toolCallID : nil
            }
        )

        for toolCall in toolCalls where toolCall.result == nil && !completedToolCallIDs.contains(toolCall.id) {
            try? Task.checkCancellation()
            if cancelledConversations.contains(conversationID) {
                return false
            }

            insertStatusMessage(
                conversationID: conversationID,
                content: String(
                    localized: "status.executing-tool",
                    defaultValue: "正在\(toolCall.displayDescription ?? "执行工具")…"
                )
            )

            var result = await toolManager.execute(
                toolCall,
                conversationID: conversationID,
                turnID: turnIDs[conversationID]
            )
            if case let .suspend(suspension) = result.turnControl,
               suspension.toolCallID == nil {
                let boundSuspension = AgentTurnSuspension(
                    suspensionID: suspension.suspensionID,
                    conversationID: suspension.conversationID,
                    toolCallID: toolCall.id,
                    kind: suspension.kind,
                    payload: suspension.payload
                )
                result = LumiToolResult(
                    content: result.content,
                    duration: result.duration,
                    isError: result.isError,
                    imageAttachments: result.imageAttachments,
                    turnControl: .suspend(boundSuspension)
                )
            }

            kernel.messageManager?.updateToolCallResult(
                result,
                toolCallID: toolCall.id,
                assistantMessageID: assistantMessage.id,
                in: conversationID
            )

            let toolResultMessage = LumiChatMessage(
                conversationID: conversationID,
                role: .tool,
                content: result.content,
                turnID: turnIDs[conversationID],
                isError: result.isError,
                metadata: LumiImageAttachmentMetadata.encode(result.imageAttachments),
                toolCallID: toolCall.id
            )
            kernel.messageManager?.insertMessage(toolResultMessage, to: conversationID)
            postMessageSavedNotification(message: toolResultMessage, conversationID: conversationID)
            completedToolCallIDs.insert(toolCall.id)

            if case let .suspend(suspension) = result.turnControl {
                if Self.verbose {
                    Self.logger.info("\(Self.t)工具请求暂停（\(toolCall.name)），等待批次中的下一个调用")
                }
                suspensions[conversationID] = suspension
                awaitingConversations.insert(conversationID)
                return true
            }
        }

        return false
    }

    /// Rebuilds a suspension from the persisted assistant tool-call result.
    /// This makes a suspended turn recoverable after the manager is recreated.
    func persistedSuspension(
        for conversationID: UUID,
        suspensionID: String? = nil
    ) -> AgentTurnSuspension? {
        let messages = kernel?.messageManager?.messages(for: conversationID) ?? []
        for message in messages.reversed() where message.role == .assistant {
            for toolCall in (message.toolCalls ?? []).reversed() {
                if case let .suspend(suspension) = toolCall.result?.turnControl,
                   suspension.conversationID == conversationID,
                   suspensionID == nil || suspension.suspensionID == suspensionID {
                    return suspension
                }
            }
        }
        return nil
    }
}
