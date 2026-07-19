import Foundation
import LLMKit
import HttpKit
import LumiCoreKit

/// 智谱 API（OpenAI 兼容协议）
public final class ZhipuAPIProvider: LumiLLMProvider, @unchecked Sendable {
    public static let shortName = "ZhiPu API"
    public static let apiKeyHelpURL: String? = "https://open.bigmodel.cn/usercenter/apikeys"
    
    public static let info = LumiLLMProviderInfo(
        id: "zhipu-api",
        displayName: LumiPluginLocalization.string("智谱 API", bundle: .module),
        description: LumiPluginLocalization.string("Zhipu AI GLM (OpenAI-compatible)", bundle: .module),
        defaultModel: "glm-4.7",
        availableModels: [
            "glm-5.2",
            "glm-5.1",
            "glm-5-turbo",
            "glm-5",
            "glm-4.7",
            "glm-4.6",
            "glm-4.5",
            "glm-4.5-air",
        ],
        contextWindowSizes: [
            "glm-5.2": 1_000_000,
            "glm-5.1": 1_000_000,
            "glm-5-turbo": 1_000_000,
            "glm-5": 1_000_000,
            "glm-4.7": 128_000,
            "glm-4.6": 200_000,
            "glm-4.5": 128_000,
            "glm-4.5-air": 128_000
        ],
        modelCapabilities: [
            "glm-5.2": .init(supportsVision: true, supportsTools: true),
            "glm-5.1": .init(supportsVision: true, supportsTools: true),
            "glm-5-turbo": .init(supportsVision: true, supportsTools: true),
            "glm-5": .init(supportsVision: true, supportsTools: true),
            "glm-4.7": .init(supportsVision: false, supportsTools: true),
            "glm-4.6": .init(supportsVision: true, supportsTools: true),
            "glm-4.5": .init(supportsVision: true, supportsTools: true),
            "glm-4.5-air": .init(supportsVision: true, supportsTools: true)
        ],
        websiteURL: URL(string: "https://www.bigmodel.cn/")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_ZhipuAPI"
    )
    
    private let adapter: OpenAICompatibleProviderAdapter
    private let apiService: LLMAPIService
    
    public init(
        configuration: OpenAICompatibleProviderConfiguration? = nil,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        let config = configuration ?? OpenAICompatibleProviderConfiguration(
            baseURL: "https://open.bigmodel.cn/api/paas/v4/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: false,
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
        await OpenAICompatibleAvailability.chatPing(
            model: model,
            adapter: adapter,
            apiService: apiService,
            buildRequest: { url, apiKey in
                adapter.buildRequest(url: url, apiKey: apiKey)
            },
            resolveAPIKey: lumiResolveAPIKey
        )
    }
    
    public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }
    
    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        ErrorDispositionResolver.disposition(for: error, context: context)
    }
    
    public func errorRenderKind(for error: Error) -> String? {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return ZhipuRenderKind.apiKeyMissing
        }
        
        if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error) {
            return ZhipuRenderKind.http(statusCode)
        }
        
        return ZhipuRenderKind.requestFailed
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