import Foundation
import KernelCore
import KitLLM
import KitSuperLog
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessage

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
