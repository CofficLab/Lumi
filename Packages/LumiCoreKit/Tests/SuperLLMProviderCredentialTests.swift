import AgentToolKit
import Foundation
import HttpKit
import LLMKit
import Testing
@testable import LumiCoreKit

private final class CredentialTestProvider: SuperLLMProvider {
    static let id = "credential-test"
    static let displayName = "Credential Test"
    static let description = "Test"
    static let apiKeyStorageKey = "LumiCoreKit_CredentialTest_Key"
    static let defaultModel = "test"

    init() {}

    var baseURL: String { "https://example.com" }

    func buildRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(Self.getApiKey(), forHTTPHeaderField: "Authorization")
        return request
    }

    func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] { [:] }

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [AgentToolKit.ToolCall]?) {
        ("", nil)
    }

    func parseStreamChunk(data: Data) throws -> StreamChunk? { nil }

    func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] { [:] }

    func streamChat(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        maxThinkingLength: Int,
        onChunk: @escaping @Sendable (StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> ChatMessage {
        try await RemoteLLMProviderTransport.streamChat(
            provider: self,
            messages: messages,
            config: config,
            tools: tools,
            maxThinkingLength: maxThinkingLength,
            onChunk: onChunk,
            onRequestStart: onRequestStart
        )
    }

    func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
    ) async throws -> ChatMessage {
        try await RemoteLLMProviderTransport.sendMessage(
            provider: self,
            messages: messages,
            config: config,
            tools: tools
        )
    }

    func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        .chatPing()
    }
}

private final class NoKeyProvider: SuperLLMProvider {
    static let id = "no-key"
    static let displayName = "No Key"
    static let description = "Test"
    static let apiKeyStorageKey = ""
    static let defaultModel = "test"

    init() {}

    var baseURL: String { "" }

    func buildRequest(url: URL) -> URLRequest { URLRequest(url: url) }

    func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] { [:] }

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [AgentToolKit.ToolCall]?) {
        ("", nil)
    }

    func parseStreamChunk(data: Data) throws -> StreamChunk? { nil }

    func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] { [:] }

    func streamChat(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        maxThinkingLength: Int,
        onChunk: @escaping @Sendable (StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> ChatMessage {
        try await RemoteLLMProviderTransport.streamChat(
            provider: self,
            messages: messages,
            config: config,
            tools: tools,
            maxThinkingLength: maxThinkingLength,
            onChunk: onChunk,
            onRequestStart: onRequestStart
        )
    }

    func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
    ) async throws -> ChatMessage {
        try await RemoteLLMProviderTransport.sendMessage(
            provider: self,
            messages: messages,
            config: config,
            tools: tools
        )
    }

    func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        .chatPing()
    }
}

@Suite("SuperLLMProvider Credentials", .serialized)
struct SuperLLMProviderCredentialTests {
    @Test("getApiKey and setApiKey round-trip")
    func apiKeyRoundTrip() {
        defer { CredentialTestProvider.removeApiKey() }

        CredentialTestProvider.setApiKey("sk-test-round-trip")
        #expect(CredentialTestProvider.getApiKey() == "sk-test-round-trip")
        #expect(CredentialTestProvider.hasApiKey)
    }

    @Test("empty apiKeyStorageKey skips credential requirement")
    func noKeyRequired() {
        #expect(NoKeyProvider.requiresStoredApiKey == false)
        #expect(NoKeyProvider.hasApiKey)
        #expect(throws: Never.self) { try NoKeyProvider.validateCredentials() }
    }

    @Test("validateCredentials throws when key missing")
    func validateThrowsWhenMissing() {
        defer { CredentialTestProvider.removeApiKey() }
        CredentialTestProvider.removeApiKey()

        #expect(throws: LLMServiceError.apiKeyEmpty) {
            try CredentialTestProvider.validateCredentials()
        }
    }

    @Test("sendMessage validates credentials before transport")
    func sendMessageValidatesCredentials() async {
        defer { CredentialTestProvider.removeApiKey() }
        CredentialTestProvider.removeApiKey()

        let provider = CredentialTestProvider()
        let config = LLMConfig(model: CredentialTestProvider.defaultModel, providerId: CredentialTestProvider.id)
        let messages = [ChatMessage(role: .user, conversationId: UUID(), content: "Hi")]

        await #expect(throws: LLMServiceError.apiKeyEmpty) {
            try await provider.sendMessage(messages: messages, config: config, tools: nil)
        }
    }

    @Test("streamChat validates credentials before transport")
    func streamChatValidatesCredentials() async {
        defer { CredentialTestProvider.removeApiKey() }
        CredentialTestProvider.removeApiKey()

        let provider = CredentialTestProvider()
        let config = LLMConfig(model: CredentialTestProvider.defaultModel, providerId: CredentialTestProvider.id)
        let messages = [ChatMessage(role: .user, conversationId: UUID(), content: "Hi")]

        await #expect(throws: LLMServiceError.apiKeyEmpty) {
            try await provider.streamChat(
                messages: messages,
                config: config,
                tools: nil,
                maxThinkingLength: 1_000,
                onChunk: { _ in },
                onRequestStart: { _ in }
            )
        }
    }
}
