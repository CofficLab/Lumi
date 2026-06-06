import Foundation
import AgentToolKit
import HttpKit
import LLMKit

/// 远程 HTTP 供应商在 `streamChat` / `sendMessage` 中可复用的传输 helper（非协议默认实现）。
public enum RemoteLLMProviderTransport {
    public static func streamChat<P: SuperLLMProvider>(
        provider: P,
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        maxThinkingLength: Int,
        onChunk: @escaping @Sendable (StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> ChatMessage {
        try config.validate()
        try P.validateCredentials()
        return try await RemoteLLMClient.streamChat(
            provider: provider,
            messages: messages,
            config: config,
            tools: tools,
            apiService: LLMAPIService(),
            maxThinkingLength: maxThinkingLength,
            onChunk: onChunk,
            onRequestStart: onRequestStart
        )
    }

    public static func sendMessage<P: SuperLLMProvider>(
        provider: P,
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
    ) async throws -> ChatMessage {
        try config.validate()
        try P.validateCredentials()
        return try await RemoteLLMClient.sendChat(
            provider: provider,
            messages: messages,
            config: config,
            tools: tools,
            apiService: LLMAPIService()
        )
    }
}
