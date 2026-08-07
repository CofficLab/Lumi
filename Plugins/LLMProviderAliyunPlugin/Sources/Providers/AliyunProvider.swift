import Foundation
import HttpKit
import LLMKit
import LumiKernel
import LumiKernel
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
            .init(
                id: "qwen3.7-plus",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: true, supportsTools: true, supportsThinking: true)
            ),
            .init(
                id: "qwen3.6-plus",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: true, supportsTools: true, supportsThinking: true)
            ),
            .init(
                id: "qwen3.5-plus",
                contextWindowSize: 131_072,
                capabilities: .init(supportsVision: true, supportsTools: true, supportsThinking: true)
            ),
            .init(
                id: "qwen3-max-2026-01-23",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: true, supportsThinking: true)
            ),
            .init(
                id: "qwen3-coder-next",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: false, supportsThinking: true)
            ),
            .init(
                id: "qwen3-coder-plus",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: false, supportsThinking: true)
            ),
            .init(
                id: "kimi-k2.5",
                contextWindowSize: 262_144,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "glm-5",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "glm-4.7",
                contextWindowSize: 128_000,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "MiniMax-M2.5",
                contextWindowSize: 204_800,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
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
