import Foundation
import HttpKit
import LLMKit
import LumiKernel
import LumiKernel
import LumiKernel

public final class OpenRouterProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "openrouter",
        displayName: LumiPluginLocalization.string("OpenRouter", bundle: .module),
        description: LumiPluginLocalization.string("Multi-Provider LLM Router", bundle: .module),
        defaultModel: "alibaba/qwen3.5-397b",
        availableModels: [
            .init(
                id: "alibaba/qwen3.5-397b",
                contextWindowSize: 131_072,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "anthropic/claude-haiku-4-5-20251001",
                contextWindowSize: 200_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingSupport: .fourLevel)
            ),
            .init(
                id: "anthropic/claude-opus-4-5-20251101",
                contextWindowSize: 200_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingSupport: .fourLevel)
            ),
            .init(
                id: "anthropic/claude-sonnet-4-5-20250929",
                contextWindowSize: 200_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingSupport: .fourLevel)
            ),
            .init(
                id: "bytedance-seed/seedream-4.5",
                contextWindowSize: 32_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "deepseek/deepseek-v3.1",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "google/gemma-3-27b-it:free",
                contextWindowSize: 131_072,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "google/gemini-pro-2.5",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "meta-llama/llama-3.3-70b-instruct",
                contextWindowSize: 131_072,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "minimax/minimax-m2.1",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "minimax/minimax-m2.5:free",
                contextWindowSize: 204_800,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "nvidia/nemotron-3-super-120b-a12b:free",
                contextWindowSize: 131_072,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "openai/gpt-4o",
                contextWindowSize: 128_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "openai/gpt-5",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingSupport: .fourLevel)
            ),
            .init(
                id: "openai/gpt-5-mini",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true, thinkingSupport: .fourLevel)
            ),
            .init(
                id: "openai/gpt-oss-20b:free",
                contextWindowSize: 131_072,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "qwen/qwen3.6-plus",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "stepfun/step-3.5-flash:free",
                contextWindowSize: 256_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "z-ai/glm-4.5-air:free",
                contextWindowSize: 131_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
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
            acceptsFunctionScopedToolCallID: true,
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
