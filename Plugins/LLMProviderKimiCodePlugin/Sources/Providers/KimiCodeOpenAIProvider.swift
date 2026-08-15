import Foundation
import LLMKit
import KernelLumi

public final class KimiCodeOpenAIProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "kimi-code-openai",
        displayName: LumiPluginLocalization.string("Kimi Code (OpenAI)", bundle: .module),
        description: LumiPluginLocalization.string("Kimi Code API via OpenAI-compatible endpoint.", bundle: .module),
        defaultModel: "k3",
        availableModels: [
            .init(id: "k3", displayName: "Kimi K3", contextWindowSize: 1_000_000,
                  capabilities: .init(supportsVision: true, supportsTools: true)),
            .init(id: "k3-256k", displayName: "Kimi K3 256K", contextWindowSize: 256_000,
                  capabilities: .init(supportsVision: true, supportsTools: true)),
            .init(id: "kimi-for-coding", displayName: "Kimi K2.7 Code", contextWindowSize: 256_000,
                  capabilities: .init(supportsVision: true, supportsTools: true)),
            .init(id: "kimi-for-coding-highspeed", displayName: "Kimi K2.7 Code High Speed", contextWindowSize: 256_000,
                  capabilities: .init(supportsVision: true, supportsTools: true)),
        ],
        websiteURL: URL(string: "https://www.moonshot.cn/")!,
        apiFormat: .openAI,
        apiKeyStorageKey: KimiCodePlugin.apiKeyStorageKey
    )

    private let apiService: KimiCodeOpenAIService

    public init(
        baseURL: String = "https://api.kimi.com/coding/v1/chat/completions",
        network: (any NetworkProviding)? = nil
    ) {
        self.apiService = KimiCodeOpenAIService(baseURL: baseURL, network: network)
    }

    public func lumiResolveAPIKey() throws -> String {
        let key = KimiCodePlugin.currentApiKey
        guard !key.isEmpty else {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return key
    }

    public func hasApiKey() -> Bool { KimiCodePlugin.hasApiKey }
    public func getApiKey() -> String { KimiCodePlugin.currentApiKey }
    public func setApiKey(_ apiKey: String) { KimiCodePlugin.setApiKey(apiKey) }
    public func removeApiKey() { KimiCodePlugin.removeApiKey() }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw KimiCodeOpenAIProviderError.invalidRequest("Conversation is empty")
        }
        let body = KimiCodeRequestBuilder.body(for: request)
        let toolNameMap = KimiCodeRequestBuilder.toolNameMap(for: request)
        guard let url = URL(string: apiService.baseURL) else {
            throw KimiCodeOpenAIProviderError.invalidRequest("Invalid Kimi Code URL")
        }
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(try lumiResolveAPIKey())", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestStartedAt = Date()
        let collector = KimiCodeChatMessageCollector(
            message: KimiCodeChatMessage.assembling(
                conversationID: conversationID,
                providerID: Self.info.id,
                modelName: request.model,
                requestStartedAt: requestStartedAt
            )
        )

        try await apiService.send(request: httpRequest, body: body) { event in
            if let error = event.error {
                collector.mutate { $0.isError = true; $0.rawErrorDetail = error }
                return false
            }
            // 模型回传的工具名是 sanitize 后的，按映射还原为 Lumi 注册 id 后再合并。
            var mappedEvent = event
            if !toolNameMap.isEmpty {
                mappedEvent.toolDeltas = event.toolDeltas.map { delta in
                    guard let name = delta.name, let restored = toolNameMap[name] else { return delta }
                    return KimiCodeToolDelta(id: delta.id, name: restored, arguments: delta.arguments)
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
            throw KimiCodeOpenAIProviderError.api(message.rawErrorDetail ?? "Kimi Code returned an error")
        }
        if message.hitMaxTokensWithoutOutput {
            throw KimiCodeOpenAIProviderError.maxTokensExceeded(message.outputTokenCount)
        }
        if message.content.isEmpty && (message.toolCalls?.isEmpty ?? true) {
            throw KimiCodeOpenAIProviderError.invalidResponse("Kimi Code returned an empty response")
        }
        return message.toLumiChatMessage()
    }

    func ping(model: String) async throws {
        guard let url = URL(string: apiService.baseURL) else {
            throw KimiCodeOpenAIProviderError.invalidRequest("Invalid Kimi Code URL")
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
        if let error = error as? KimiCodeOpenAIProviderError {
            return error.llmErrorDisposition
        }
        return context.attempt < context.maxAttempts ? .retryable() : .nonRetryable
    }

    public func errorRenderKind(for error: Error) -> String? {
        if let statusCode = LumiProviderHTTPErrorParsing.statusCode(from: error) {
            return KimiCodeRenderKind.http(statusCode)
        }
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           let statusCode = LumiProviderHTTPErrorParsing.statusCode(from: description) {
            return KimiCodeRenderKind.http(statusCode)
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