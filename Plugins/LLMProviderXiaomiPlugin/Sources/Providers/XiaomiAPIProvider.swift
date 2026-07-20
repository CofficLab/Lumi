import Foundation
import LLMKit
import LumiLLMProviderSupport
import  HttpKit
import LumiKernel

/// 小米 API（OpenAI 兼容协议）
public final class XiaomiAPIProvider: LumiLLMProvider, @unchecked Sendable {
    public static let apiKeyHelpURL: String? = "https://platform.xiaomimimo.com/console/api-keys"
    
    public static let info = LumiLLMProviderInfo(
        id: "xiaomi-api",
        displayName: LumiPluginLocalization.string("Xiaomi API", bundle: .module),
        description: LumiPluginLocalization.string("Xiaomi API (OpenAI-compatible)", bundle: .module),
        defaultModel: "mimo-v2.5-pro",
        availableModels: [
            "mimo-v2.5-pro",
            "mimo-v2.5",
            "mimo-v2.5-tts",
            "mimo-v2.5-tts-voiceclone",
            "mimo-v2.5-tts-voicedesign"
        ],
        contextWindowSizes: [
            "mimo-v2.5-pro": 1_000_000,
            "mimo-v2.5": 1_000_000,
            "mimo-v2.5-tts": 131_072,
            "mimo-v2.5-tts-voiceclone": 131_072,
            "mimo-v2.5-tts-voicedesign": 131_072
        ],
        modelCapabilities: [
            "mimo-v2.5-pro": .init(supportsVision: true, supportsTools: true),
            "mimo-v2.5": .init(supportsVision: false, supportsTools: true),
            "mimo-v2.5-tts": .init(supportsVision: false, supportsTools: false, supportsTTS: true),
            "mimo-v2.5-tts-voiceclone": .init(supportsVision: false, supportsTools: false, supportsTTS: true),
            "mimo-v2.5-tts-voicedesign": .init(supportsVision: false, supportsTools: false, supportsTTS: true)
        ],
        websiteURL: URL(string: "https://www.mi.com")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_XiaomiAPI"
    )
    
    private let adapter: OpenAICompatibleProviderAdapter
    private let apiService: LLMAPIService
    
    public init(
        configuration: OpenAICompatibleProviderConfiguration? = nil,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        let config = configuration ?? OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.xiaomimimo.com/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: false,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
        self.adapter = OpenAICompatibleProviderAdapter(configuration: config)
        self.apiService = apiService
    }
    
    // MARK: - Internal Access for AvailabilityService
    
    var internalAdapter: OpenAICompatibleProviderAdapter { adapter }
    var internalApiService: LLMAPIService { apiService }
    
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
        XiaomiErrorHandling.renderKind(for: error)
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