import Foundation
import HttpKit
import LLMKit
import LumiKernel
import LumiKernel
import LumiKernel

public final class FeifeimiaoProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "feifeimiao",
        displayName: LumiPluginLocalization.string("Feifeimiao", bundle: .module),
        description: LumiPluginLocalization.string("LLM API by feifeimiao", bundle: .module),
        defaultModel: "gpt-5.5",
        availableModels: [
            "gpt-5.5",
            "gpt-5.4",
            "gpt-5.4-mini",
            "gpt-5.3",
            "gpt-5.2"
        ],
        contextWindowSizes: [
            "gpt-5.5": 1_000_000,
            "gpt-5.4": 1_000_000,
            "gpt-5.4-mini": 400_000,
            "gpt-5.3": 400_000,
            "gpt-5.2": 400_000
        ],
        modelCapabilities: [
            "gpt-5.5": .init(supportsVision: true, supportsTools: true),
            "gpt-5.4": .init(supportsVision: true, supportsTools: true),
            "gpt-5.4-mini": .init(supportsVision: true, supportsTools: true),
            "gpt-5.3": .init(supportsVision: true, supportsTools: true),
            "gpt-5.2": .init(supportsVision: true, supportsTools: true)
        ],
        websiteURL: URL(string: "https://feifeimiao.top")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_Feifeimiao"
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
            baseURL: "https://api.feifeimiao.top/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
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