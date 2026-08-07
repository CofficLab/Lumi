import Foundation
import HttpKit
import LLMKit
import LumiKernel
import LumiKernel
import LumiKernel
import os
import SuperLogKit

public final class StepFunProvider: LumiLLMProvider, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "🌟"
    nonisolated static let verbose: Int = 0
    public static let shortName = "StepFun StepPlan"
    
    public static let info = LumiLLMProviderInfo(
        id: "stepfun",
        displayName: LumiPluginLocalization.string("StepFun StepPlan", bundle: .module),
        description: LumiPluginLocalization.string("StepFun StepPlan AI", bundle: .module),
        defaultModel: "step-3.5-flash",
        availableModels: [
            .init(
                id: "step-3.7-flash",
                contextWindowSize: 262_144,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "step-router-v1",
                contextWindowSize: 262_144,
                capabilities: .init(supportsVision: false, supportsTools: false)
            ),
            .init(
                id: "stepaudio-2.5-chat",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "stepaudio-2.5-tts",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: false)
            ),
            .init(
                id: "stepaudio-2.5-asr",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: false)
            ),
            .init(
                id: "stepaudio-2.5-realtime",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "step-image-edit-2",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: true, supportsTools: false)
            ),
            .init(
                id: "step-3.5-flash-2603",
                contextWindowSize: 262_144,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "step-3.5-flash",
                contextWindowSize: 262_144,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
        ],
        websiteURL: URL(string: "https://www.stepfun.com/")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_StepFun"
    )
    
    public static let apiKeyHelpURL: String? = "https://www.stepfun.com/#/api"
    
    private let adapter: OpenAICompatibleProviderAdapter
    private let apiService: LLMAPIService
    
    public init(
        configuration: OpenAICompatibleProviderConfiguration? = nil,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        let config = configuration ?? OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.stepfun.com/step_plan/v1/chat/completions",
            additionalHeaders: ["Accept": "text/event-stream"],
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