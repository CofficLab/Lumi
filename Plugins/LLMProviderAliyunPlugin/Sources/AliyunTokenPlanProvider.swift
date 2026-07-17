import Foundation
import HttpKit
import LLMKit
import LumiCoreKit
import LumiLLMProviderSupport

public final class AliyunTokenPlanProvider: LumiLLMProvider, @unchecked Sendable {
    public static let shortName = "Aliyun"
    public static let apiKeyHelpURL: String? = "https://help.aliyun.com/zh/model-studio/get-api-key"
    
    public static let info = LumiLLMProviderInfo(
        id: "aliyun-tokenplan",
        displayName: LumiPluginLocalization.string("阿里云 TokenPlan", bundle: .module),
        description: LumiPluginLocalization.string("阿里云 DashScope Token Plan", bundle: .module),
        defaultModel: "qwen3.6-plus",
        availableModels: [
            "qwen3.6-flash",
            "qwen3.6-plus",
            "qwen3.7-plus",
            "qwen3.7-max",
            "qwen-image-2.0",
            "qwen-image-2.0-pro",
            "wan2.7-image",
            "wan2.7-image-pro",
            "deepseek-v3.2",
            "deepseek-v4-flash",
            "deepseek-v4-pro",
            "kimi-k2.5",
            "kimi-k2.6",
            "kimi-k2.7-code",
            "glm-5",
            "glm-5.1",
            "glm-5.2",
            "MiniMax-M2.5",
        ],
        contextWindowSizes: [
            "qwen3.6-flash": 1_000_000,
            "qwen3.6-plus": 1_000_000,
            "qwen3.7-plus": 1_000_000,
            "qwen3.7-max": 1_000_000,
            "qwen-image-2.0": 32_768,
            "qwen-image-2.0-pro": 32_768,
            "wan2.7-image": 32_768,
            "wan2.7-image-pro": 32_768,
            "deepseek-v3.2": 131_072,
            "deepseek-v4-flash": 131_072,
            "deepseek-v4-pro": 131_072,
            "kimi-k2.5": 262_144,
            "kimi-k2.6": 262_144,
            "kimi-k2.7-code": 262_144,
            "glm-5": 1_000_000,
            "glm-5.1": 1_000_000,
            "glm-5.2": 1_000_000,
            "MiniMax-M2.5": 204_800
        ],
        modelCapabilities: [
            "qwen3.6-flash": .init(supportsVision: true, supportsTools: true),
            "qwen3.6-plus": .init(supportsVision: true, supportsTools: true),
            "qwen3.7-plus": .init(supportsVision: true, supportsTools: true),
            "qwen3.7-max": .init(supportsVision: false, supportsTools: true),
            "qwen-image-2.0": .init(supportsVision: true, supportsTools: false),
            "qwen-image-2.0-pro": .init(supportsVision: true, supportsTools: false),
            "wan2.7-image": .init(supportsVision: false, supportsTools: false),
            "wan2.7-image-pro": .init(supportsVision: false, supportsTools: false),
            "deepseek-v3.2": .init(supportsVision: false, supportsTools: true),
            "deepseek-v4-flash": .init(supportsVision: true, supportsTools: true),
            "deepseek-v4-pro": .init(supportsVision: true, supportsTools: true),
            "kimi-k2.5": .init(supportsVision: false, supportsTools: true),
            "kimi-k2.6": .init(supportsVision: true, supportsTools: true),
            "kimi-k2.7-code": .init(supportsVision: true, supportsTools: true),
            "glm-5": .init(supportsVision: true, supportsTools: true),
            "glm-5.1": .init(supportsVision: true, supportsTools: true),
            "glm-5.2": .init(supportsVision: true, supportsTools: true),
            "MiniMax-M2.5": .init(supportsVision: false, supportsTools: true)
        ],
        websiteURL: URL(string: "https://www.aliyun.com/product/bailian")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_Aliyun"
    )
    
    private let adapter: AnthropicCompatibleProviderAdapter
    private let apiService: LLMAPIService
    
    public init(
        configuration: AnthropicCompatibleProviderConfiguration? = nil,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        let config = configuration ?? AnthropicCompatibleProviderConfiguration(
            baseURL: "https://token-plan.cn-beijing.maas.aliyuncs.com/apps/anthropic/v1/messages"
        )
        self.adapter = AnthropicCompatibleProviderAdapter(configuration: config)
        self.apiService = apiService
    }
    
    // MARK: - Internal Access for AvailabilityService
    
    var internalAdapter: AnthropicCompatibleProviderAdapter { adapter }
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