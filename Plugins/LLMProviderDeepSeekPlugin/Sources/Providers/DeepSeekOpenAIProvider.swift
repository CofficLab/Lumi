import Foundation
import LLMKit
import KernelLumi

public final class DeepSeekOpenAIProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "deepseek",
        displayName: LumiPluginLocalization.string("DeepSeek", bundle: .module),
        description: LumiPluginLocalization.string("DeepSeek AI", bundle: .module),
        defaultModel: "deepseek-v4-flash",
        availableModels: [
            .init(
                id: "deepseek-v4-flash",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: true, thinkingAndReasoning: .fourLevel)
            ),
            .init(
                id: "deepseek-v4-pro",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: true, thinkingAndReasoning: .fourLevel)
            ),
        ],
        websiteURL: URL(string: "https://www.deepseek.com/")!,
        apiKeyStorageKey: DeepSeekPlugin.apiKeyStorageKey
    )

    private let apiService: DeepSeekOpenAIService

    public init(
        baseURL: String = "https://api.deepseek.com/v1/chat/completions",
        network: (any NetworkProviding)? = nil
    ) {
        self.apiService = DeepSeekOpenAIService(baseURL: baseURL, network: network)
    }

    // MARK: - LumiLLMProvider Protocol

    public func lumiResolveAPIKey() throws -> String {
        let key = DeepSeekPlugin.currentApiKey
        guard !key.isEmpty else {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return key
    }

    public func hasApiKey() -> Bool {
        DeepSeekPlugin.hasApiKey
    }

    public func getApiKey() -> String {
        DeepSeekPlugin.currentApiKey
    }

    public func setApiKey(_ apiKey: String) {
        DeepSeekPlugin.setApiKey(apiKey)
    }

    public func removeApiKey() {
        DeepSeekPlugin.removeApiKey()
    }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw DeepSeekOpenAIProviderError.invalidRequest("Conversation is empty")
        }
        let body = DeepSeekRequestBuilder.body(for: request)
        let toolNameMap = DeepSeekRequestBuilder.toolNameMap(for: request)
        guard let url = URL(string: apiService.baseURL) else {
            throw DeepSeekOpenAIProviderError.invalidRequest("Invalid DeepSeek URL")
        }
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(try lumiResolveAPIKey())", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestStartedAt = Date()
        let collector = DeepSeekChatMessageCollector(
            message: DeepSeekChatMessage.assembling(
                conversationID: conversationID,
                providerID: Self.info.id,
                modelName: request.model,
                requestStartedAt: requestStartedAt,
                streamingStartedAt: nil
            )
        )

        try await apiService.send(request: httpRequest, body: body) { event in
            // 协议层错误：标记消息为错误并停止消费。
            if let error = event.error {
                collector.mutate { $0.isError = true; $0.rawErrorDetail = error }
                return false
            }
            // 模型回传的工具名是 sanitize 后的，按映射还原为 Lumi 注册 id 后再合并。
            var mappedEvent = event
            if !toolNameMap.isEmpty {
                mappedEvent.toolDeltas = event.toolDeltas.map { delta in
                    guard let name = delta.name, let restored = toolNameMap[name] else { return delta }
                    return DeepSeekToolDelta(id: delta.id, name: restored, arguments: delta.arguments)
                }
            }
            collector.mutate { $0.merge(mappedEvent) }
            if let content = event.content, !content.isEmpty {
                await onChunk(LumiStreamChunk(content: content, eventTitle: "生成中"))
            }
            if let reasoning = event.reasoning, !reasoning.isEmpty {
                await onChunk(LumiStreamChunk(content: reasoning, isThinking: true, eventTitle: "思考中"))
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
            throw DeepSeekOpenAIProviderError.api(message.rawErrorDetail ?? "DeepSeek returned an error")
        }
        // 撞上 max_tokens 上限且没有任何可见输出(OpenAI 端点 finish_reason="length",
        // 典型:thinking 吃掉全部输出预算)。先于 empty response 检查抛出,给出明确原因。
        if message.hitMaxTokensWithoutOutput {
            throw DeepSeekOpenAIProviderError.maxTokensExceeded(message.outputTokenCount)
        }
        if message.content.isEmpty && (message.toolCalls?.isEmpty ?? true) {
            throw DeepSeekOpenAIProviderError.invalidResponse("DeepSeek returned an empty response")
        }
        return message.toLumiChatMessage()
    }

    func ping(model: String) async throws {
        guard let url = URL(string: apiService.baseURL) else {
            throw DeepSeekOpenAIProviderError.invalidRequest("Invalid DeepSeek URL")
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
        if let error = error as? DeepSeekOpenAIProviderError {
            return error.llmErrorDisposition
        }
        return context.attempt < context.maxAttempts
            ? .retryable()
            : .nonRetryable
    }

    public func errorRenderKind(for error: Error) -> String? {
        // 先从错误类型中提取状态码
        if let statusCode = LumiProviderHTTPErrorParsing.statusCode(from: error) {
            return DeepSeekRenderKind.http(statusCode)
        }
        // 如果错误类型不支持，尝试从错误描述中提取
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            if let statusCode = LumiProviderHTTPErrorParsing.statusCode(from: description) {
                return DeepSeekRenderKind.http(statusCode)
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
