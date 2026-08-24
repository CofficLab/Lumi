import Foundation
import KernelLumi
import os
import SuperLogKit

// MARK: - Tool Execution

extension AgentTurnRunner {

    /// Finds the latest assistant tool-call message that still has an
    /// unexecuted call. Tool results are no longer embedded in the assistant
    /// message, so the durable completion marker is the separate `.tool`
    /// message with the matching `toolCallID`.
    func incompleteToolCallMessage(in conversationID: UUID) -> LumiChatMessage? {
        incompleteToolCallMessage(
            messages: kernel?.messageManager?.messages(for: conversationID) ?? []
        )
    }

    /// Snapshot-based variant: reuses an already-fetched message history to
    /// avoid a redundant DB fetch + sort. `executeTurnLoop` fetches once per
    /// iteration and threads the snapshot through its helpers.
    func incompleteToolCallMessage(messages: [LumiChatMessage]) -> LumiChatMessage? {
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
        latestAssistantToolCalls(
            messages: kernel?.messageManager?.messages(for: conversationID) ?? []
        )
    }

    /// Snapshot-based variant. See `incompleteToolCallMessage(messages:)`.
    func latestAssistantToolCalls(messages: [LumiChatMessage]) -> [LumiToolCall]? {
        messages.reversed()
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
        await executePendingToolCalls(
            in: assistantMessage,
            conversationID: conversationID,
            messages: kernel?.messageManager?.messages(for: conversationID) ?? []
        )
    }

    /// Snapshot-based variant: accepts an already-fetched message history used
    /// to seed the set of completed tool-call IDs. Inserts performed inside the
    /// batch are tracked via the local `completedToolCallIDs` set, so the
    /// passed snapshot only needs to reflect state before this batch resumed.
    func executePendingToolCalls(
        in assistantMessage: LumiChatMessage,
        conversationID: UUID,
        messages: [LumiChatMessage]
    ) async -> Bool {
        guard let kernel,
              kernel.toolManager != nil,
              let toolCalls = assistantMessage.toolCalls
        else {
            Self.logger.error("\(Self.t)ToolManager 不可用，无法继续工具批次")
            failedConversations.insert(conversationID)
            return false
        }

        var completedToolCallIDs = Set(
            messages.compactMap { message in
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

            var result = await executeToolCall(
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
        return persistedSuspension(
            messages: messages,
            conversationID: conversationID,
            suspensionID: suspensionID
        )
    }

    /// Snapshot-based variant. See `incompleteToolCallMessage(messages:)`.
    func persistedSuspension(
        messages: [LumiChatMessage],
        conversationID: UUID,
        suspensionID: String? = nil
    ) -> AgentTurnSuspension? {
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
