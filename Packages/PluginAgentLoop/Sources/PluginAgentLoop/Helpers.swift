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
import KitSuperLog

extension Message {
    var llmMessage: LLMMessage {
        LLMMessage(
            role: KitLLM.MessageRole(rawValue: role.rawValue) ?? .unknown,
            content: content,
            toolCalls: toolCalls?.map { LLMToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
            toolCallID: toolCallID,
            reasoningContent: reasoningContent,
            images: []
        )
    }
}

/// 将生命周期钩子返回的 LLM 消息恢复为 AgentLoop 的消息模型。
/// 工具调用声明必须保留，否则后续的 tool_result 没有对应的 assistant tool_use。
func messageFromLLMMessage(_ message: LLMMessage, conversationID: UUID) -> Message {
    Message(
        conversationID: conversationID,
        role: .init(rawValue: message.role.rawValue) ?? .system,
        content: message.content,
        toolCallID: message.toolCallID,
        reasoningContent: message.reasoningContent,
        toolCalls: message.toolCalls?.map {
            MessageToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
        }
    )
}

// 消除 KitLLMVendors.ToolCall 与 KitAgentTool.ToolCall 的歧义
typealias AgentLoopToolCall = KitAgentTool.ToolCall
