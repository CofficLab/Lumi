import Foundation
import HttpKit
import LLMKit
import LumiCoreKit
import LLMKit
import LumiCoreKit

public final class OpenRouterProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "openrouter",
        displayName: LumiPluginLocalization.string("OpenRouter", bundle: .module),
        description: LumiPluginLocalization.string("Multi-Provider LLM Router", bundle: .module),
        defaultModel: "alibaba/qwen3.5-397b",
        availableModels: [
            "alibaba/qwen3.5-397b",
            "anthropic/claude-haiku-4-5-20251001",
            "anthropic/claude-opus-4-5-20251101",
            "anthropic/claude-sonnet-4-5-20250929",
            "bytedance-seed/seedream-4.5",
            "deepseek/deepseek-v3.1",
            "google/gemma-3-27b-it:free",
            "google/gemini-pro-2.5",
            "meta-llama/llama-3.3-70b-instruct",
            "minimax/minimax-m2.1",
            "minimax/minimax-m2.5:free",
            "nvidia/nemotron-3-super-120b-a12b:free",
            "openai/gpt-4o",
            "openai/gpt-5",
            "openai/gpt-5-mini",
            "openai/gpt-oss-20b:free",
            "qwen/qwen3.6-plus",
            "stepfun/step-3.5-flash:free",
            "z-ai/glm-4.5-air:free"
        ],
        contextWindowSizes: [
            "alibaba/qwen3.5-397b": 131_072,
            "anthropic/claude-haiku-4-5-20251001": 200_000,
            "anthropic/claude-opus-4-5-20251101": 200_000,
            "anthropic/claude-sonnet-4-5-20250929": 200_000,
            "bytedance-seed/seedream-4.5": 32_000,
            "deepseek/deepseek-v3.1": 1_000_000,
            "google/gemma-3-27b-it:free": 131_072,
            "google/gemini-pro-2.5": 1_000_000,
            "meta-llama/llama-3.3-70b-instruct": 131_072,
            "minimax/minimax-m2.1": 1_000_000,
            "minimax/minimax-m2.5:free": 204_800,
            "nvidia/nemotron-3-super-120b-a12b:free": 131_072,
            "openai/gpt-4o": 128_000,
            "openai/gpt-5": 400_000,
            "openai/gpt-5-mini": 400_000,
            "openai/gpt-oss-20b:free": 131_072,
            "qwen/qwen3.6-plus": 1_000_000,
            "stepfun/step-3.5-flash:free": 256_000,
            "z-ai/glm-4.5-air:free": 131_000
        ],
        modelCapabilities: [
            "alibaba/qwen3.5-397b": .init(supportsVision: false, supportsTools: true),
            "anthropic/claude-haiku-4-5-20251001": .init(supportsVision: true, supportsTools: true),
            "anthropic/claude-opus-4-5-20251101": .init(supportsVision: true, supportsTools: true),
            "anthropic/claude-sonnet-4-5-20250929": .init(supportsVision: true, supportsTools: true),
            "bytedance-seed/seedream-4.5": .init(supportsVision: true, supportsTools: true),
            "deepseek/deepseek-v3.1": .init(supportsVision: false, supportsTools: true),
            "google/gemma-3-27b-it:free": .init(supportsVision: true, supportsTools: true),
            "google/gemini-pro-2.5": .init(supportsVision: true, supportsTools: true),
            "meta-llama/llama-3.3-70b-instruct": .init(supportsVision: false, supportsTools: true),
            "minimax/minimax-m2.1": .init(supportsVision: false, supportsTools: true),
            "minimax/minimax-m2.5:free": .init(supportsVision: false, supportsTools: true),
            "nvidia/nemotron-3-super-120b-a12b:free": .init(supportsVision: false, supportsTools: true),
            "openai/gpt-4o": .init(supportsVision: true, supportsTools: true),
            "openai/gpt-5": .init(supportsVision: true, supportsTools: true),
            "openai/gpt-5-mini": .init(supportsVision: true, supportsTools: true),
            "openai/gpt-oss-20b:free": .init(supportsVision: false, supportsTools: true),
            "qwen/qwen3.6-plus": .init(supportsVision: true, supportsTools: true),
            "stepfun/step-3.5-flash:free": .init(supportsVision: true, supportsTools: true),
            "z-ai/glm-4.5-air:free": .init(supportsVision: true, supportsTools: true)
        ],
        websiteURL: URL(string: "https://openrouter.ai/")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_OpenRouter"
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
            baseURL: "https://openrouter.ai/api/v1/chat/completions",
            additionalHeaders: ["HTTP-Referer": "Lumi", "X-Title": "Lumi"],
            includeUsageInStreamOptions: false,
            returnsEmptyChunkWhenNoDelta: true,
            acceptsFunctionScopedToolCallID: true
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