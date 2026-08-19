import Foundation
import KitLLM
import ProviderMessage

// MARK: - Message Helpers

extension AgentLoopProvider {
    func insertToolResultMessage(
        _ result: MessageToolResult,
        toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) {
        let toolMessage = Message(
            conversationID: conversationID,
            role: .tool,
            content: result.content,
            turnID: turnID,
            isError: result.isError,
            toolCallID: toolCallID
        )
        messages.insertMessage(toolMessage, to: conversationID)
    }

    func insertStatusMessage(conversationID: UUID, content: String) {
        let status = Message(
            conversationID: conversationID,
            role: .status,
            content: content,
            metadata: ["isTransientStatus": "true"]
        )
        messages.insertMessage(status, to: conversationID)
    }

    func appendError(in conversationID: UUID, content: String, turnID: UUID? = nil) async {
        let errorMessage = Message(
            conversationID: conversationID,
            role: .error,
            content: content,
            turnID: turnID
        )
        messages.insertMessage(errorMessage, to: conversationID)
    }

    /// 从 `Error` 构造错误消息，透传渲染元数据（`renderKind` / `rawErrorDetail`），
    /// 让 Key 缺失等错误命中专用渲染器（如 API Key 输入卡）；同时带上会话绑定的
    /// 供应商 id，供渲染器解析供应商（否则 provider==nil 会把输入框 disabled）。
    func appendError(in conversationID: UUID, error: Error, turnID: UUID? = nil) async {
        let renderInfo = error as? any LLMErrorRenderInfo
        let errorMessage = Message(
            conversationID: conversationID,
            role: .error,
            content: error.localizedDescription,
            turnID: turnID,
            providerID: resolvedProviderID(for: conversationID),
            rawErrorDetail: renderInfo?.rawErrorDetail,
            renderKind: renderInfo?.renderKind
        )
        messages.insertMessage(errorMessage, to: conversationID)
    }
}

// MARK: - Message Query

extension AgentLoopProvider {
    func incompleteToolCallMessage(in conversationID: UUID) -> Message? {
        incompleteToolCallMessage(messages: messages.messages(for: conversationID))
    }

    func incompleteToolCallMessage(messages: [Message]) -> Message? {
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

    func latestAssistantToolCalls(in conversationID: UUID) -> [MessageToolCall]? {
        latestAssistantToolCalls(messages: messages.messages(for: conversationID))
    }

    func latestAssistantToolCalls(messages: [Message]) -> [MessageToolCall]? {
        messages.reversed()
            .first(where: { $0.role == .assistant && !($0.toolCalls ?? []).isEmpty })?
            .toolCalls
    }
}
