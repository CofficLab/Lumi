import AgentToolKit
import Foundation
import KitLLM
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderToolManager
import SuperLogKit

// MARK: - Tool Execution

extension AgentLoopProvider {
    /// 授权边界：`chat` 拒绝工具、`autonomous` 直接执行、`build` 高风险需确认。
    func executeToolCall(
        _ toolCall: MessageToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> MessageToolResult {
        let tool = AgentLoopToolCall(
            id: toolCall.id,
            name: toolCall.name,
            arguments: toolCall.arguments
        )
        let automationLevel = conversations.automationLevel(for: conversationID)
        if Self.verbose {
            let risk = toolManager.riskLevel(for: tool)
            Self.logger.info("\(Self.t)执行工具前: tool=\(toolCall.name), automationLevel=\(automationLevel.rawValue), riskLevel=\(String(describing: risk)), argumentsLen=\(toolCall.arguments.count)")
        }
        switch automationLevel {
        case .chat:
            return MessageToolResult(
                content: "Tool execution was blocked because this conversation is in Chat mode.",
                isError: true
            )
        case .autonomous:
            return convertResult(
                await toolManager.execute(tool, conversationID: conversationID, turnID: turnID)
            )
        case .build:
            let riskLevel = toolManager.riskLevel(for: tool) ?? .high
            guard riskLevel.requiresPermission else {
                return convertResult(
                    await toolManager.execute(tool, conversationID: conversationID, turnID: turnID)
                )
            }
            return makeToolApprovalResult(for: toolCall, riskLevel: riskLevel, conversationID: conversationID)
        }
    }

    func executeApprovedToolCall(_ toolCall: MessageToolCall, conversationID: UUID) async -> MessageToolResult {
        let tool = AgentLoopToolCall(
            id: toolCall.id,
            name: toolCall.name,
            arguments: toolCall.arguments
        )
        return convertResult(
            await toolManager.execute(tool, conversationID: conversationID, turnID: turnIDs[conversationID])
        )
    }

    func isToolApprovalGranted(_ answer: String) -> Bool {
        switch answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "允许", "同意", "是", "allow", "approve", "approved", "yes":
            return true
        default:
            return false
        }
    }

    func makeToolApprovalResult(
        for toolCall: MessageToolCall,
        riskLevel: CommandRiskLevel,
        conversationID: UUID
    ) -> MessageToolResult {
        let suspensionID = "approval:\(toolCall.id)"
        let operation = toolCall.displayDescription ?? toolCall.name
        let payload = ToolApprovalPayload(
            toolCallId: suspensionID,
            question: "此操作被判定为\(riskLevel.displayName)，是否允许执行？\n\(operation)",
            options: ["允许", "拒绝"],
            mode: "yes_no",
            conversationId: conversationID.uuidString,
            verbosity: "standard"
        )
        let content = (try? String(data: JSONEncoder().encode(payload), encoding: .utf8))
            ?? "Unable to create tool approval request."
        let suspension = AgentLoopSuspension(
            suspensionID: suspensionID,
            conversationID: conversationID,
            toolCallID: toolCall.id,
            kind: Self.toolApprovalSuspensionKind,
            payload: content
        )
        suspensions[conversationID] = suspension
        return MessageToolResult(
            content: content,
            isError: false,
            awaitingUserResponse: true,
            interactionState: .waiting
        )
    }

    /// 把 `ToolCallResult` 转换为渲染层 `MessageToolResult`。
    func convertResult(_ result: ToolCallResult) -> MessageToolResult {
        MessageToolResult(
            content: result.content,
            duration: result.duration,
            isError: result.isError,
            imageAttachments: result.images.map {
                MessageImageAttachment(data: $0.data.base64EncodedString(), mimeType: $0.mimeType)
            },
            awaitingUserResponse: result.awaitingUserResponse
        )
    }
}

// MARK: - Incomplete Tool-Call Batch

extension AgentLoopProvider {
    /// 按顺序续跑中断的工具批次（resume 后已完成的调用跳过，下一调用可独立挂起）。
    /// - Returns: `true` 表示批次再次因用户输入挂起。
    func executePendingToolCalls(
        in assistantMessage: Message,
        conversationID: UUID
    ) async -> Bool {
        await executePendingToolCalls(
            in: assistantMessage,
            conversationID: conversationID,
            snapshot: messages.messages(for: conversationID)
        )
    }

    func executePendingToolCalls(
        in assistantMessage: Message,
        conversationID: UUID,
        snapshot: [Message]
    ) async -> Bool {
        guard let toolCalls = assistantMessage.toolCalls else {
            failedConversations.insert(conversationID)
            return false
        }

        var completedToolCallIDs = Set(
            snapshot.compactMap { message in
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

            var result = await executeToolCall(toolCall, conversationID: conversationID, turnID: turnIDs[conversationID])
            if result.awaitingUserResponse, let suspension = suspensions[conversationID],
               suspension.toolCallID == nil {
                let bound = AgentLoopSuspension(
                    suspensionID: suspension.suspensionID,
                    conversationID: suspension.conversationID,
                    toolCallID: toolCall.id,
                    kind: suspension.kind,
                    payload: suspension.payload
                )
                suspensions[conversationID] = bound
                result = MessageToolResult(
                    content: result.content,
                    isError: result.isError,
                    awaitingUserResponse: true
                )
            }
            // 通用交互工具（AskUser 等）：构造用户输入挂起点。
            if result.awaitingUserResponse, suspensions[conversationID] == nil {
                let generic = AgentLoopSuspension(
                    suspensionID: "userInput:\(toolCall.id)",
                    conversationID: conversationID,
                    toolCallID: toolCall.id,
                    kind: "userInput",
                    payload: result.content
                )
                suspensions[conversationID] = generic
            }

            messages.updateToolCallResult(result, toolCallID: toolCall.id, assistantMessageID: assistantMessage.id, in: conversationID)
            insertToolResultMessage(result, toolCallID: toolCall.id, conversationID: conversationID, turnID: turnIDs[conversationID])
            completedToolCallIDs.insert(toolCall.id)

            if result.awaitingUserResponse {
                return true
            }
        }

        return false
    }
}

// MARK: - Tool Approval Payload

private struct ToolApprovalPayload: Codable {
    let toolCallId: String
    let question: String
    let options: [String]
    let mode: String
    let conversationId: String
    let verbosity: String
}
