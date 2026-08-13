import Foundation
import HttpKit
import LLMKit
import KernelLumi
import KernelLumi
import KernelLumi

public final class AiRouterProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "airouter",
        displayName: LumiPluginLocalization.string("AiRouter", bundle: .module),
        description: LumiPluginLocalization.string("LLM Router by airouter.org", bundle: .module),
        defaultModel: "gpt-5",
        availableModels: [
            .init(
                id: "gpt-5.1-codex-max",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "gpt-5.2-codex",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "gpt-5.4-mini",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "gpt-5",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "gpt-5.1-codex-mini",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "gpt-5.2",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "gpt-5.3-codex",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "gpt-5.4",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "gpt-5-codex",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "gpt-5.1",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "gpt-5.1-codex",
                contextWindowSize: 400_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
        ],
        websiteURL: URL(string: "https://airouter.org")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_AiRouter"
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
            baseURL: "https://api.airouter.org/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
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
