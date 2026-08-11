import Foundation
import LLMKit
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
            .init(id: "qwen3.7-plus", contextWindowSize: 1_000_000, capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .fourLevel)),
            .init(id: "qwen3.6-plus", contextWindowSize: 1_000_000, capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .fourLevel)),
            .init(id: "qwen3.5-plus", contextWindowSize: 131_072, capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .fourLevel)),
            .init(id: "qwen3-max-2026-01-23", contextWindowSize: 1_000_000, capabilities: .init(supportsVision: false, supportsTools: true, thinkingAndReasoning: .fourLevel)),
            .init(id: "qwen3-coder-next", contextWindowSize: 1_000_000, capabilities: .init(supportsVision: false, supportsTools: false, thinkingAndReasoning: .fourLevel)),
            .init(id: "qwen3-coder-plus", contextWindowSize: 1_000_000, capabilities: .init(supportsVision: false, supportsTools: false, thinkingAndReasoning: .fourLevel)),
            .init(id: "kimi-k2.5", contextWindowSize: 262_144, capabilities: .init(supportsVision: true, supportsTools: true)),
            .init(id: "glm-5", contextWindowSize: 1_000_000, capabilities: .init(supportsVision: false, supportsTools: true)),
            .init(id: "glm-4.7", contextWindowSize: 128_000, capabilities: .init(supportsVision: false, supportsTools: true)),
            .init(id: "MiniMax-M2.5", contextWindowSize: 204_800, capabilities: .init(supportsVision: false, supportsTools: true)),
        ],
        websiteURL: URL(string: "https://www.aliyun.com/product/bailian")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_Aliyun"
    )
    
    private let apiService: AliyunAnthropicService
    
    public init(baseURL: String = "https://coding.dashscope.aliyuncs.com/apps/anthropic", network: (any NetworkProviding)? = nil) {
        self.apiService = AliyunAnthropicService(baseURL: baseURL, network: network)
    }

    public func lumiResolveAPIKey() throws -> String {
        try LumiAPIKeyTools.resolve(storageKey: Self.info._apiKeyStorageKey, displayName: Self.info.displayName)
    }
    public func hasApiKey() -> Bool { LumiAPIKeyTools.has(storageKey: Self.info._apiKeyStorageKey) }
    public func getApiKey() -> String { LumiAPIKeyTools.get(storageKey: Self.info._apiKeyStorageKey) }
    public func setApiKey(_ apiKey: String) { LumiAPIKeyTools.set(apiKey, storageKey: Self.info._apiKeyStorageKey) }
    public func removeApiKey() { LumiAPIKeyTools.remove(storageKey: Self.info._apiKeyStorageKey) }
    
    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }
    
    public func sendStreaming(_ request: LumiLLMRequest, onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw AliyunProviderError.invalidRequest("Conversation is empty")
        }
        let body = AliyunAnthropicRequestBuilder.body(for: request)
        let toolNameMap = AliyunAnthropicRequestBuilder.toolNameMap(for: request)
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let apiKey = try lumiResolveAPIKey()

        let requestStartedAt = Date()
        let collector = AliyunChatMessageCollector(message: AliyunChatMessage.assembling(
            conversationID: conversationID, providerID: Self.info.id, modelName: request.model, requestStartedAt: requestStartedAt,
            toolNameMap: toolNameMap
        ))
        
        try await apiService.send(apiKey: apiKey, body: bodyData) { event in
            if let error = event.error {
                collector.mutate { $0.isError = true; $0.rawErrorDetail = error }
                return false
            }
            collector.mutate { $0.merge(event) }
            if let content = event.textDelta, !content.isEmpty {
                await onChunk(LumiStreamChunk(content: content, eventTitle: "生成中"))
            }
            if let thinking = event.thinkingDelta, !thinking.isEmpty {
                await onChunk(LumiStreamChunk(content: thinking, isThinking: true, eventTitle: "思考中"))
            }
            if event.done {
                collector.mutate { $0.finalize() }
                await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))
                return false
            }
            return true
        }
        
        let message = collector.snapshot()
        if message.isError { throw AliyunProviderError.api(message.rawErrorDetail ?? "Aliyun returned an error") }
        if message.hitMaxTokensWithoutOutput { throw AliyunProviderError.maxTokensExceeded(message.outputTokenCount) }
        if message.content.isEmpty && (message.toolCalls?.isEmpty ?? true) { throw AliyunProviderError.invalidResponse("Aliyun returned an empty response") }
        return message.toLumiChatMessage()
    }
    
    func ping(model: String) async throws {
        let body: [String: Any] = ["model": model, "messages": [["role": "user", "content": "ping"]], "max_tokens": 1, "stream": false]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await apiService.sendOnce(apiKey: try lumiResolveAPIKey(), body: bodyData)
    }
    
    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AliyunAvailabilityService.checkAvailability(provider: self, model: model)
    }
    public func providerStatus() -> LumiLLMProviderStatus? { LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self) }
    
    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        if let error = error as? AliyunProviderError { return error.llmErrorDisposition }
        if case LumiLLMProviderSupportError.missingAPIKey = error { return .nonRetryable }
        if let statusCode = LumiProviderHTTPErrorParsing.statusCode(from: error), statusCode == 401 { return .nonRetryable }
        return context.attempt < context.maxAttempts ? .retryable() : .nonRetryable
    }
    
    public func errorRenderKind(for error: Error) -> String? {
        if case LumiLLMProviderSupportError.missingAPIKey = error { return AliyunRenderKind.apiKeyMissing }
        if let statusCode = LumiProviderHTTPErrorParsing.statusCode(from: error) { return AliyunRenderKind.http(statusCode) }
        return AliyunRenderKind.requestFailed
    }
    
    public func makeErrorMessage(conversationID: UUID, request: LumiLLMRequest, error: Error, disposition: LumiLLMErrorDisposition) -> LumiChatMessage {
        LumiLLMProviderErrorSupport.makeErrorMessage(providerID: Self.info.id, conversationID: conversationID, request: request, error: error, disposition: disposition, renderKind: errorRenderKind(for: error))
    }
}
