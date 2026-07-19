import Foundation
import HttpKit
import LLMKit
import LumiKernel

public final class KimiCodeAnthropicProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "kimi-code-anthropic",
        displayName: LumiPluginLocalization.string("Kimi Code (Anthropic)", bundle: .module),
        description: LumiPluginLocalization.string("Kimi Code API via Anthropic-compatible endpoint.", bundle: .module),
        defaultModel: "k3",
        availableModels: [
            "k3",
            "kimi-for-coding",
            "kimi-for-coding-highspeed"
        ],
        contextWindowSizes: [
            "k3": 1_000_000,
            "kimi-for-coding": 256_000,
            "kimi-for-coding-highspeed": 256_000
        ],
        modelCapabilities: [
            "k3": .init(supportsVision: true, supportsTools: true),
            "kimi-for-coding": .init(supportsVision: true, supportsTools: true),
            "kimi-for-coding-highspeed": .init(supportsVision: true, supportsTools: true)
        ],
        modelDisplayNames: [
            "k3": "Kimi K3",
            "kimi-for-coding": "Kimi K2.7 Code",
            "kimi-for-coding-highspeed": "Kimi K2.7 Code High Speed"
        ],
        websiteURL: URL(string: "https://www.moonshot.cn/")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_KimiCode"
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
            baseURL: "https://api.kimi.com/coding/v1/messages",
            fallbackBaseURLs: [],
            additionalHeaders: [:],
            apiVersion: "2023-06-01",
            defaultMaxTokens: 8192
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
        await AvailabilityService.checkAvailabilityForAnthropic(provider: self, model: model)
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