import Foundation
import HttpKit
import LLMKit
import LumiKernel
import LumiKernel
import LumiKernel

public final class MegaLLMProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "megallm",
        displayName: LumiPluginLocalization.string("MegaLLM", bundle: .module),
        description: LumiPluginLocalization.string("MegaLLM AI", bundle: .module),
        defaultModel: "gpt-5-mini",
        availableModels: [
            "alibaba-qwen3.5-397b",
            "claude-haiku-4-5-20251001",
            "claude-opus-4-5-20251101",
            "claude-opus-4-6",
            "claude-sonnet-4-5-20250929",
            "claude-sonnet-4-6",
            "deepseek-ai/deepseek-v3.1",
            "grok-4.1-fast-reasoning",
            "gpt-5-mini",
            "gpt-5.3-codex",
            "llama3.3-70b-instruct",
            "minimaxai/minimax-m2.1",
            "newclaude-opus-4-6"
        ],
        contextWindowSizes: [
            "alibaba-qwen3.5-397b": 131_072,
            "claude-haiku-4-5-20251001": 200_000,
            "claude-opus-4-5-20251101": 200_000,
            "claude-opus-4-6": 200_000,
            "claude-sonnet-4-5-20250929": 200_000,
            "claude-sonnet-4-6": 200_000,
            "deepseek-ai/deepseek-v3.1": 1_000_000,
            "grok-4.1-fast-reasoning": 1_000_000,
            "gpt-5-mini": 400_000,
            "gpt-5.3-codex": 400_000,
            "llama3.3-70b-instruct": 131_072,
            "minimaxai/minimax-m2.1": 1_000_000,
            "newclaude-opus-4-6": 200_000
        ],
        modelCapabilities: [
            "alibaba-qwen3.5-397b": .init(supportsVision: false, supportsTools: true),
            "claude-haiku-4-5-20251001": .init(supportsVision: true, supportsTools: true),
            "claude-opus-4-5-20251101": .init(supportsVision: true, supportsTools: true),
            "claude-opus-4-6": .init(supportsVision: true, supportsTools: true),
            "claude-sonnet-4-5-20250929": .init(supportsVision: true, supportsTools: true),
            "claude-sonnet-4-6": .init(supportsVision: true, supportsTools: true),
            "deepseek-ai/deepseek-v3.1": .init(supportsVision: false, supportsTools: true),
            "grok-4.1-fast-reasoning": .init(supportsVision: true, supportsTools: true),
            "gpt-5-mini": .init(supportsVision: true, supportsTools: true),
            "gpt-5.3-codex": .init(supportsVision: true, supportsTools: true),
            "llama3.3-70b-instruct": .init(supportsVision: false, supportsTools: true),
            "minimaxai/minimax-m2.1": .init(supportsVision: false, supportsTools: true),
            "newclaude-opus-4-6": .init(supportsVision: true, supportsTools: true)
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
            acceptsFunctionScopedToolCallID: false
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