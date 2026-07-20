import Foundation
import HttpKit
import LLMKit
import LumiLLMProviderSupport
import LumiCoreLLMProvider
import LumiCoreMessage
import LumiKernel

public final class AliyunProvider: LumiLLMProvider, @unchecked Sendable {
    public static let shortName = "Aliyun"
    public static let apiKeyHelpURL: String? = "https://help.aliyun.com/zh/model-studio/get-api-key"
    
    public static let info = LumiLLMProviderInfo(
        id: "aliyun",
        displayName: LumiPluginLocalization.string("阿里云 CodingPlan", bundle: .module),
        description: LumiPluginLocalization.string("阿里云 DashScope Coding Plan", bundle: .module),
        defaultModel: "qwen3.6-plus",
        availableModels: [
            "qwen3.7-plus",
            "qwen3.6-plus",
            "qwen3.5-plus",
            "qwen3-max-2026-01-23",
            "qwen3-coder-next",
            "qwen3-coder-plus",
            "kimi-k2.5",
            "glm-5",
            "glm-4.7",
            "MiniMax-M2.5",
        ],
        contextWindowSizes: [
            "qwen3.7-plus": 1_000_000,
            "qwen3.6-plus": 1_000_000,
            "qwen3.5-plus": 131_072,
            "qwen3-max-2026-01-23": 1_000_000,
            "qwen3-coder-next": 1_000_000,
            "qwen3-coder-plus": 1_000_000,
            "kimi-k2.5": 262_144,
            "glm-5": 1_000_000,
            "glm-4.7": 128_000,
            "MiniMax-M2.5": 204_800
        ],
        modelCapabilities: [
            "qwen3.7-plus": .init(supportsVision: true, supportsTools: true),
            "qwen3.6-plus": .init(supportsVision: true, supportsTools: true),
            "qwen3.5-plus": .init(supportsVision: true, supportsTools: true),
            "qwen3-max-2026-01-23": .init(supportsVision: false, supportsTools: true),
            "qwen3-coder-next": .init(supportsVision: false, supportsTools: false),
            "qwen3-coder-plus": .init(supportsVision: false, supportsTools: false),
            "kimi-k2.5": .init(supportsVision: true, supportsTools: true),
            "glm-5": .init(supportsVision: false, supportsTools: true),
            "glm-4.7": .init(supportsVision: false, supportsTools: true),
            "MiniMax-M2.5": .init(supportsVision: false, supportsTools: true)
        ],
        websiteURL: URL(string: "https://www.aliyun.com/product/bailian")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_Aliyun"
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
            baseURL: "https://coding.dashscope.aliyuncs.com/apps/anthropic/v1/messages"
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
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return AliyunRenderKind.apiKeyMissing
        }
        
        if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error) {
            return AliyunRenderKind.http(statusCode)
        }
        
        return AliyunRenderKind.requestFailed
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