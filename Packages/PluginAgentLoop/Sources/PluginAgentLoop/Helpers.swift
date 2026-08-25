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

// 消除 KitLLMVendors.ToolCall 与 KitAgentTool.ToolCall 的歧义
typealias AgentLoopToolCall = KitAgentTool.ToolCall
