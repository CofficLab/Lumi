import Foundation
import HttpKit
import LLMKit
import LumiKernel

/// MiniMax Token Plan 提供商
public final class MiniMaxTokenPlanProvider: LumiLLMProvider, @unchecked Sendable {
    public static let shortName = "MiniMax"
    public static let apiKeyHelpURL: String? = "https://platform.minimaxi.com/user-center/basic-information/Interface-key"
    
    public static let info = LumiLLMProviderInfo(
        id: "minimax-tokenplan",
        displayName: LumiPluginLocalization.string("MiniMax TokenPlan", bundle: .module),
        description: LumiPluginLocalization.string("MiniMax Token Plan (Anthropic-compatible)", bundle: .module),
        defaultModel: "MiniMax-M2.7",
        availableModels: [
            "MiniMax-M3",
            "MiniMax-M2.7",
            "MiniMax-M2.7-highspeed",
            "MiniMax-M2.5",
            "MiniMax-M2",
            "MiniMax-Text-01"
        ],
        contextWindowSizes: [
            "MiniMax-M3": 204_800,
            "MiniMax-M2.7": 204_800,
            "MiniMax-M2.7-highspeed": 204_800,
            "MiniMax-M2.5": 204_800,
            "MiniMax-M2": 131_072,
            "MiniMax-Text-01": 4_000_000
        ],
        modelCapabilities: [
            "MiniMax-M3": .init(supportsVision: true, supportsTools: true),
            "MiniMax-M2.7": .init(supportsVision: true, supportsTools: true),
            "MiniMax-M2.7-highspeed": .init(supportsVision: true, supportsTools: true),
            "MiniMax-M2.5": .init(supportsVision: false, supportsTools: true),
            "MiniMax-M2": .init(supportsVision: false, supportsTools: true),
            "MiniMax-Text-01": .init(supportsVision: false, supportsTools: false)
        ],
        websiteURL: URL(string: "https://platform.minimaxi.com/")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_MiniMax"
    )
    
    private let adapter: AnthropicCompatibleProviderAdapter
    private let apiService: LLMAPIService
    
    public init(
        configuration: AnthropicCompatibleProviderConfiguration? = nil,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        let config = configuration ?? AnthropicCompatibleProviderConfiguration(
            baseURL: "https://api.minimax.chat/anthropic/v1/messages"
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
            return MiniMaxRenderKind.apiKeyMissing
        }
        
        if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error) {
            return MiniMaxRenderKind.http(statusCode)
        }
        
        return MiniMaxRenderKind.requestFailed
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