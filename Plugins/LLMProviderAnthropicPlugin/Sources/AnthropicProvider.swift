import Foundation
import HttpKit
import LLMKit
import LumiLLMProviderSupport
import LumiKernel
import LumiKernel
import LumiKernel

public final class AnthropicProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "anthropic",
        displayName: LumiPluginLocalization.string("Anthropic", bundle: .module),
        description: LumiPluginLocalization.string("Claude AI by Anthropic", bundle: .module),
        defaultModel: "claude-sonnet-4-20250514",
        availableModels: [
            "claude-sonnet-4-20250514",
            "claude-opus-4-20250514",
            "claude-3-5-sonnet-20241022",
            "claude-3-5-sonnet-20240620",
            "claude-3-opus-20240229",
            "claude-3-sonnet-20240229",
            "claude-3-haiku-20240307"
        ],
        contextWindowSizes: [
            "claude-sonnet-4-20250514": 200_000,
            "claude-opus-4-20250514": 200_000,
            "claude-3-5-sonnet-20241022": 200_000,
            "claude-3-5-sonnet-20240620": 200_000,
            "claude-3-opus-20240229": 200_000,
            "claude-3-sonnet-20240229": 200_000,
            "claude-3-haiku-20240307": 200_000
        ],
        modelCapabilities: [
            "claude-sonnet-4-20250514": .init(supportsVision: true, supportsTools: true),
            "claude-opus-4-20250514": .init(supportsVision: true, supportsTools: true),
            "claude-3-5-sonnet-20241022": .init(supportsVision: true, supportsTools: true),
            "claude-3-5-sonnet-20240620": .init(supportsVision: true, supportsTools: true),
            "claude-3-opus-20240229": .init(supportsVision: true, supportsTools: true),
            "claude-3-sonnet-20240229": .init(supportsVision: true, supportsTools: true),
            "claude-3-haiku-20240307": .init(supportsVision: true, supportsTools: true)
        ],
        websiteURL: URL(string: "https://www.anthropic.com/")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_Anthropic"
    )
    
    private let adapter: AnthropicCompatibleProviderAdapter

    // MARK: - Internal Access for AvailabilityService

    var internalAdapter: AnthropicCompatibleProviderAdapter { adapter }
    var internalApiService: LLMAPIService { apiService }
    private let apiService: LLMAPIService
    
    public init(
        configuration: AnthropicCompatibleProviderConfiguration? = nil,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        let config = configuration ?? AnthropicCompatibleProviderConfiguration(
            baseURL: "https://api.anthropic.com/v1/messages"
        )
        self.adapter = AnthropicCompatibleProviderAdapter(configuration: config)
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
        try await LumiStreamingRequestSupport.sendAnthropicCompatibleStreaming(
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