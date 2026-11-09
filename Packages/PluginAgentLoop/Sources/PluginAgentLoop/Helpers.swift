import KitAgentTool
import Combine
import Foundation
import KitLLM
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import LumiLoggingKit
extension Message {
    var llmMessage: LLMMessage {
        llmMessage(toolImages: [])
    }

    func llmMessage(
        toolImages: [KitLLM.MessageImage],
        omittedArgumentKeys: [String: Set<String>] = [:]
    ) -> LLMMessage {
        let userImages: [KitLLM.MessageImage] = UserAttachmentMetadata
            .decodeImageAttachments(from: metadata)
            .compactMap { attachment -> KitLLM.MessageImage? in
                guard let data = Data(base64Encoded: attachment.base64Data) else { return nil }
                return KitLLM.MessageImage(data: data, mimeType: attachment.mimeType)
            }
        let userFiles = role == .user
            ? UserAttachmentMetadata.decodeFileAttachments(from: metadata)
            : []
        let contentWithFileAttachments = UserAttachmentMetadata.appendingFileAttachments(
            userFiles,
            to: content
        )

        return LLMMessage(
            role: KitLLM.MessageRole(rawValue: role.rawValue) ?? .unknown,
            content: contentWithFileAttachments,
            toolCalls: toolCalls?.map { toolCall in
                let arguments = ToolCallContextArguments.scrubbed(
                    toolCall.arguments,
                    omitting: omittedArgumentKeys[toolCall.name] ?? []
                )
                return LLMToolCall(id: toolCall.id, name: toolCall.name, arguments: arguments)
            },
            toolCallID: toolCallID,
            reasoningContent: reasoningContent,
            redactedThinking: redactedThinkingData?.map {
                KitLLM.LLMRedactedThinkingBlock(data: $0)
            },
            // 工具失败必须在协议层可见，不能被当成普通成功文本。
            isError: isError,
            // 工具结果图片必须挂在独立的 tool 消息上，不能成为 assistant content。
            images: role == .user ? userImages : (role == .tool ? toolImages : [])
        )
    }
}

/// 收集各工具声明的不进入模型上下文的参数键，按工具名索引。
///
/// 声明为空的工具不进入结果，`llmMessages` 因此对它们保持原样。
func contextOmittedArgumentKeys(for tools: [any SuperAgentTool]) -> [String: Set<String>] {
    var result: [String: Set<String>] = [:]
    for tool in tools {
        let keys = tool.contextOmittedArgumentKeys
        guard !keys.isEmpty else { continue }
        result[tool.name] = keys
    }
    return result
}

/// 将持久化消息转换为 LLM 消息，并把 assistant 工具调用结果中的图片
/// 关联到对应的 tool 消息。图片仍只保存在 assistant 的嵌套结果中，避免
/// 为传输格式额外复制一份大体积 base64 数据。
func llmMessages(
    from messages: [Message],
    omittedArgumentKeys: [String: Set<String>] = [:]
) -> [LLMMessage] {
    var pendingImagesByToolCallID: [String: [[KitLLM.MessageImage]]] = [:]
    for message in messages where message.role == .assistant {
        for toolCall in message.toolCalls ?? [] {
            let images = toolCall.result?.imageAttachments.compactMap { attachment -> KitLLM.MessageImage? in
                guard let data = Data(base64Encoded: attachment.data) else { return nil }
                return KitLLM.MessageImage(data: data, mimeType: attachment.mimeType)
            } ?? []
            guard !images.isEmpty else { continue }
            pendingImagesByToolCallID[toolCall.id, default: []].append(images)
        }
    }

    var result: [LLMMessage] = []
    result.reserveCapacity(messages.count)
    for message in messages {
        var toolImages: [KitLLM.MessageImage] = []
        if message.role == .tool,
           let toolCallID = message.toolCallID,
           var pendingImages = pendingImagesByToolCallID[toolCallID],
           !pendingImages.isEmpty {
            toolImages = pendingImages.removeFirst()
            pendingImagesByToolCallID[toolCallID] = pendingImages
        }
        result.append(
            message.llmMessage(toolImages: toolImages, omittedArgumentKeys: omittedArgumentKeys)
        )
    }
    return result
}

/// 将生命周期钩子返回的 LLM 消息恢复为 AgentLoop 的消息模型。
/// 工具调用声明必须保留，否则后续的 tool_result 没有对应的 assistant tool_use。
func messageFromLLMMessage(_ message: LLMMessage, conversationID: UUID) -> Message {
    let metadata: [String: String]
    if message.role == .user, !message.images.isEmpty {
        metadata = UserAttachmentMetadata.encodeImageAttachments(
            message.images.map {
                UserImageAttachment(
                    mimeType: $0.mimeType,
                    base64Data: $0.data.base64EncodedString()
                )
            }
        )
    } else {
        metadata = [:]
    }

    return Message(
        conversationID: conversationID,
        role: .init(rawValue: message.role.rawValue) ?? .system,
        content: message.content,
        metadata: metadata,
        isError: message.isError,
        toolCallID: message.toolCallID,
        reasoningContent: message.reasoningContent,
        toolCalls: message.toolCalls?.map {
            MessageToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
        }
    )
}

// 消除 KitLLMVendors.ToolCall 与 KitAgentTool.ToolCall 的歧义
typealias AgentLoopToolCall = KitAgentTool.ToolCall
