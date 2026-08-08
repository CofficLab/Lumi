import Foundation
import LLMKit
import LumiKernel
import SuperLogKit
import os

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
    
    private let apiService: StepFunService
    
    public init(
        baseURL: String = "https://api.stepfun.com/step_plan/v1/chat/completions",
        network: (any NetworkProviding)? = nil
    ) {
        self.apiService = StepFunService(baseURL: baseURL, network: network)
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
        guard let conversationID = request.messages.first?.conversationID else {
            throw StepFunProviderError.invalidRequest("Conversation is empty")
        }
        let body = StepFunRequestBuilder.body(for: request)
        guard let url = URL(string: apiService.baseURL) else {
            throw StepFunProviderError.invalidRequest("Invalid StepFun URL")
        }
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(try lumiResolveAPIKey())", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestStartedAt = Date()
        let collector = StepFunChatMessageCollector(
            message: StepFunChatMessage.assembling(
                conversationID: conversationID,
                providerID: Self.info.id,
                modelName: request.model,
                requestStartedAt: requestStartedAt,
                streamingStartedAt: nil
            )
        )
        
        try await apiService.send(request: httpRequest, body: body) { event in
            if let error = event.error {
                collector.mutate { $0.isError = true; $0.rawErrorDetail = error }
                return false
            }
            collector.mutate { $0.merge(event) }
            if let content = event.content, !content.isEmpty {
                await onChunk(LumiStreamChunk(content: content, eventTitle: "生成中"))
            }
            if event.done {
                collector.mutate { $0.finalize() }
                await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))
                return false
            }
            return true
        }
        
        let message = collector.snapshot()
        if message.isError {
            throw StepFunProviderError.api(message.rawErrorDetail ?? "StepFun returned an error")
        }
        if message.hitMaxTokensWithoutOutput {
            throw StepFunProviderError.maxTokensExceeded(message.outputTokenCount)
        }
        if message.content.isEmpty && (message.toolCalls?.isEmpty ?? true) {
            throw StepFunProviderError.invalidResponse("StepFun returned an empty response")
        }
        return message.toLumiChatMessage()
    }
    
    func ping(model: String) async throws {
        guard let url = URL(string: apiService.baseURL) else {
            throw StepFunProviderError.invalidRequest("Invalid StepFun URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(try lumiResolveAPIKey())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await apiService.sendOnce(
            request: request,
            body: [
                "model": model,
                "messages": [["role": "user", "content": "ping"]],
                "stream": false,
                "max_tokens": 1,
            ]
        )
    }
    
    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }
    
    public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }
    
    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        if let error = error as? StepFunProviderError {
            return error.llmErrorDisposition
        }
        return context.attempt < context.maxAttempts
            ? .retryable()
            : .nonRetryable
    }
    
    public func errorRenderKind(for error: Error) -> String? {
        if let statusCode = LumiProviderHTTPErrorParsing.statusCode(from: error) {
            return StepFunRenderKind.http(statusCode)
        }
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            if let statusCode = LumiProviderHTTPErrorParsing.statusCode(from: description) {
                return StepFunRenderKind.http(statusCode)
            }
        }
        return nil
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