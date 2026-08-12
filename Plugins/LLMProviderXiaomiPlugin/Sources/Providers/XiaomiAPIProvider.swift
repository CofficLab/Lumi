import Foundation
import LLMKit
import LumiKernel

/// 小米 API（OpenAI 兼容协议）
public final class XiaomiAPIProvider: LumiLLMProvider, @unchecked Sendable {
    public static let apiKeyHelpURL: String? = "https://platform.xiaomimimo.com/console/api-keys"

    public static let info = LumiLLMProviderInfo(
        id: "xiaomi-api",
        displayName: LumiPluginLocalization.string("Xiaomi API", bundle: .module),
        description: LumiPluginLocalization.string("Xiaomi API (OpenAI-compatible)", bundle: .module),
        defaultModel: "mimo-v2.5-pro",
        availableModels: [
            .init(
                id: "mimo-v2.5-pro",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: true, supportsTools: true)
            ),
            .init(
                id: "mimo-v2.5",
                contextWindowSize: 1_000_000,
                capabilities: .init(supportsVision: false, supportsTools: true)
            ),
            .init(
                id: "mimo-v2.5-tts",
                contextWindowSize: 131_072,
                capabilities: .init(supportsVision: false, supportsTools: false, supportsTTS: true)
            ),
            .init(
                id: "mimo-v2.5-tts-voiceclone",
                contextWindowSize: 131_072,
                capabilities: .init(supportsVision: false, supportsTools: false, supportsTTS: true)
            ),
            .init(
                id: "mimo-v2.5-tts-voicedesign",
                contextWindowSize: 131_072,
                capabilities: .init(supportsVision: false, supportsTools: false, supportsTTS: true)
            ),
        ],
        websiteURL: URL(string: "https://www.mi.com")!,
        apiKeyStorageKey: XiaomiPlugin.apiKeyStorageKeyForAPI
    )

    private let apiService: XiaomiAPIService

    public init(
        baseURL: String = "https://api.xiaomimimo.com/v1/chat/completions",
        network: (any NetworkProviding)? = nil
    ) {
        self.apiService = XiaomiAPIService(baseURL: baseURL, network: network)
    }

    // MARK: - Internal Access for AvailabilityService

    var internalAPIService: XiaomiAPIService { apiService }

    // MARK: - LumiLLMProvider Protocol

    public func lumiResolveAPIKey() throws -> String {
        let key = XiaomiPlugin.currentApiKeyForAPI
        guard !key.isEmpty else {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return key
    }

    public func hasApiKey() -> Bool {
        !XiaomiPlugin.currentApiKeyForAPI.isEmpty
    }

    public func getApiKey() -> String {
        XiaomiPlugin.currentApiKeyForAPI
    }

    public func setApiKey(_ apiKey: String) {
        XiaomiPlugin.setApiKeyForAPI(apiKey)
    }

    public func removeApiKey() {
        XiaomiPlugin.removeApiKeyForAPI()
    }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw XiaomiOpenAIProviderError.invalidRequest("Conversation is empty")
        }
        let body = XiaomiRequestBuilder.body(for: request)
        let toolNameMap = XiaomiRequestBuilder.toolNameMap(for: request)
        guard let url = URL(string: apiService.baseURL) else {
            throw XiaomiOpenAIProviderError.invalidRequest("Invalid Xiaomi URL")
        }
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(try lumiResolveAPIKey())", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestStartedAt = Date()
        let collector = XiaomiChatMessageCollector(
            message: XiaomiChatMessage.assembling(
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
                    return XiaomiToolDelta(id: delta.id, name: restored, arguments: delta.arguments)
                }
            }
            collector.mutate { $0.merge(mappedEvent) }
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
            throw XiaomiOpenAIProviderError.api(message.rawErrorDetail ?? "Xiaomi returned an error")
        }
        if message.content.isEmpty && (message.toolCalls?.isEmpty ?? true) {
            throw XiaomiOpenAIProviderError.invalidResponse("Xiaomi returned an empty response")
        }
        return message.toLumiChatMessage()
    }

    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }

    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        if let error = error as? XiaomiOpenAIProviderError {
            return error.llmErrorDisposition
        }
        return context.attempt < context.maxAttempts
            ? .retryable()
            : .nonRetryable
    }

    public func errorRenderKind(for error: Error) -> String? {
        if let statusCode = LumiProviderHTTPErrorParsing.statusCode(from: error) {
            return XiaomiRenderKind.http(statusCode)
        }
        return XiaomiErrorHandling.renderKind(for: error)
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
