import Testing
import Foundation
import AgentToolKit
import HttpKit
import LLMKit
import LumiCoreKit
@testable import LLMAvailabilityPlugin

@Test func packageLoads() async throws {
    #expect(LLMAvailabilityPlugin.policy == .alwaysOn)
}

@MainActor
@Test func availabilityCheckerUsesInjectedProviderRegistry() async throws {
    let providerInfo = LLMProviderInfo(
        id: AvailabilityMockProvider.id,
        displayName: AvailabilityMockProvider.displayName,
        shortName: AvailabilityMockProvider.shortName,
        description: AvailabilityMockProvider.description,
        websiteURL: nil,
        availableModels: AvailabilityMockProvider.availableModels,
        defaultModel: AvailabilityMockProvider.defaultModel,
        isLocal: false,
        isEnabled: true,
        contextWindowSizes: AvailabilityMockProvider.contextWindowSizes
    )
    let service = LumiCoreKit.LLMService(
        providersProvider: { [providerInfo] },
        providerTypeProvider: { providerId in
            providerId == AvailabilityMockProvider.id ? AvailabilityMockProvider.self : nil
        },
        providerFactory: { providerId in
            providerId == AvailabilityMockProvider.id ? AvailabilityMockProvider() : nil
        },
        apiKeyProvider: { providerId in
            providerId == AvailabilityMockProvider.id ? "test-key" : ""
        }
    )

    AvailabilityMockProvider.setApiKey("test-key")
    defer { AvailabilityMockProvider.removeApiKey() }

    LLMAvailabilityStore.shared.initialize(providers: [providerInfo])
    let result = await LLMAvailabilityChecker(llmService: service)
        .checkModel(providerId: AvailabilityMockProvider.id, modelId: AvailabilityMockProvider.defaultModel)

    #expect(result.isAvailable)
    #expect(result.reason == nil)
    #expect(LLMAvailabilityStore.shared.status(providerId: AvailabilityMockProvider.id, modelId: AvailabilityMockProvider.defaultModel) == .available)
}

private struct AvailabilityMockProvider: SuperLLMProvider {
    static let id = "availability-mock"
    static let displayName = "Availability Mock"
    static let shortName = "Mock"
    static let description = "Mock provider for availability tests"
    static let apiKeyStorageKey = "availability-mock-key"
    static let defaultModel = "mock-model"
    static let modelCatalog = [
        LLMModelCatalogItem(id: defaultModel, description: "Mock model", spec: LLMModelSpec(supportsVision: false, supportsTools: true))
    ]

    var baseURL: String { "https://example.com" }

    func buildRequest(url: URL) -> URLRequest {
        URLRequest(url: url)
    }

    func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        [:]
    }

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?) {
        ("", nil)
    }

    func parseResponseWithMetadata(data: Data) throws -> LLMProviderResponse {
        LLMProviderResponse(content: "", toolCalls: nil)
    }

    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        nil
    }

    func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        [:]
    }

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
        .apiKeyOnly
    }
}
