import Foundation
import HttpKit
import LLMKit
import KernelLumi
import KernelLumi
import KernelLumi

public final class MegaLLMProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "megallm",
        displayName: LumiPluginLocalization.string("MegaLLM", bundle: .module),
        description: LumiPluginLocalization.string("MegaLLM AI", bundle: .module),
        defaultModel: "gpt-5-mini",
        availableModels: [
            .init(
                id: "alibaba-qwen3.5-397b",
                contextWindowSize: 131_072,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "claude-haiku-4-5-20251001",
                contextWindowSize: 200_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .fourLevel)
            ),
            .init(
                id: "claude-opus-4-5-20251101",
                contextWindowSize: 200_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .fourLevel)
            ),
            .init(
                id: "claude-opus-4-6",
                contextWindowSize: 200_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .fourLevel)
            ),
            .init(
                id: "claude-sonnet-4-5-20250929",
                contextWindowSize: 200_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .fourLevel)
            ),
            .init(
                id: "claude-sonnet-4-6",
                contextWindowSize: 200_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .fourLevel)
            ),
            .init(
                id: "deepseek-ai/deepseek-v3.1",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "grok-4.1-fast-reasoning",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "gpt-5-mini",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .fourLevel)
            ),
            .init(
                id: "gpt-5.3-codex",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .fourLevel)
            ),
            .init(
                id: "llama3.3-70b-instruct",
                contextWindowSize: 131_072,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "minimaxai/minimax-m2.1",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "newclaude-opus-4-6",
                contextWindowSize: 200_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .fourLevel)
            ),
        ],
        websiteURL: URL(string: "https://megallm.io")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_MegaLLM"
    )
    
    private let adapter: OpenAICompatibleProviderAdapter

    // MARK: - Internal Access for AvailabilityService
    
    var internalAdapter: OpenAICompatibleProviderAdapter { adapter }
    var internalApiService: LLMAPIService { apiService }
    private let apiService: LLMAPIService
    
    public init(
        configuration: OpenAICompatibleProviderConfiguration? = nil,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        let config = configuration ?? OpenAICompatibleProviderConfiguration(
            baseURL: "https://ai.megallm.io/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: false,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false,
        )
        self.adapter = OpenAICompatibleProviderAdapter(configuration: config)
        self.apiService = apiService
    }
    
    // MARK: - LumiLLMProvider Protocol
    
    public func lumiResolveAPIKey() throws -> String {
        try LumiAPIKeyTools.resolve(
            storageKey: Self.info._apiKeyStorageKey,
            displayName: Self.info.displayName
        )
    }
    
    public func hasApiKey() -> Bool {
        LumiAPIKeyTools.has(storageKey: Self.info._apiKeyStorageKey)
    }
    
    public func getApiKey() -> String {
        LumiAPIKeyTools.get(storageKey: Self.info._apiKeyStorageKey)
    }
    
    public func setApiKey(_ apiKey: String) {
        LumiAPIKeyTools.set(apiKey, storageKey: Self.info._apiKeyStorageKey)
    }
    
    public func removeApiKey() {
        LumiAPIKeyTools.remove(storageKey: Self.info._apiKeyStorageKey)
    }
    
    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }
    
    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        try await LumiStreamingRequestSupport.sendOpenAICompatibleStreaming(
            request,
            adapter: adapter,
            apiService: apiService,
            baseURLs: [adapter.configuration.baseURL] + adapter.configuration.fallbackBaseURLs,
            resolveAPIKey: lumiResolveAPIKey,
            buildRequest: { url, apiKey in
                adapter.buildRequest(url: url, apiKey: apiKey)
            },
            onChunk: onChunk
        )
    }
    
    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }
    
    public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }
    
    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        ErrorDispositionResolver.disposition(for: error, context: context)
    }
    
    public func errorRenderKind(for error: Error) -> String? {
        nil
    }
    
    public func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        LumiLLMProviderErrorSupport.makeErrorMessage(
            providerID: Self.info.id,
            
            conversationID: conversationID,
            request: request,
            error: error,
            disposition: disposition,
            renderKind: errorRenderKind(for: error)
        )
    }
}
