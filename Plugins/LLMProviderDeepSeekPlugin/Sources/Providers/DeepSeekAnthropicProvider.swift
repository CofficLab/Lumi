import Foundation
import LLMKit
import LumiKernel

/// DeepSeek 的 Anthropic-compatible 协议实现，作为 `DeepSeekOpenAIProvider` 的兄弟 provider。
///
/// 端点：`https://api.deepseek.com/anthropic/v1/messages`
/// 鉴权：`x-api-key` + `anthropic-version: 2023-06-01`
///
/// 与 `DeepSeekOpenAIProvider`（OpenAI-compatible）共享：
/// - API Key（见 `DeepSeekPlugin.apiKeyStorageKey`）
/// - 模型列表（`deepseek-v4-flash` / `deepseek-v4-pro`）
/// - 上下文窗口与能力
///
/// 不共享：
/// - 请求 / 响应协议层（`DeepSeekAnthropicService` / `DeepSeekAnthropicEventParser` /
///   `DeepSeekAnthropicRequestBuilder`）
/// - 协议层错误类型（`DeepSeekAnthropicTransportError`）
public final class DeepSeekAnthropicProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "deepseek-anthropic",
        displayName: LumiPluginLocalization.string("DeepSeek (Anthropic Format)", bundle: .module),
        description: LumiPluginLocalization.string("DeepSeek AI via Anthropic-compatible API", bundle: .module),
        defaultModel: "deepseek-v4-flash",
        availableModels: [
            "deepseek-v4-flash",
            "deepseek-v4-pro",
        ],
        contextWindowSizes: [
            "deepseek-v4-flash": 1000000,
            "deepseek-v4-pro": 1000000,
        ],
        modelCapabilities: [
            "deepseek-v4-flash": .init(supportsVision: false, supportsTools: true),
            "deepseek-v4-pro": .init(supportsVision: false, supportsTools: true),
        ],
        websiteURL: URL(string: "https://www.deepseek.com/")!,
        apiKeyStorageKey: DeepSeekPlugin.apiKeyStorageKey
    )

    private let apiService: DeepSeekAnthropicService

    public init(
        baseURL: String = "https://api.deepseek.com/anthropic",
        network: (any NetworkProviding)? = nil
    ) {
        self.apiService = DeepSeekAnthropicService(baseURL: baseURL, network: network)
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
            throw AnthropicProviderError.invalidRequest("Conversation is empty")
        }

        // 构造请求体（已编码成 JSON Data）
        let body = AnthropicRequestBuilder.body(for: request)
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let apiKey = try lumiResolveAPIKey()

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

        try await apiService.send(apiKey: apiKey, body: bodyData) { event in
            // 协议层错误：标记消息为错误并停止消费。
            if let error = event.error {
                collector.mutate { $0.isError = true; $0.rawErrorDetail = error }
                return false
            }

            // 先在锁内合并事件，再在锁外触发 UI chunk，保持事件顺序。
            var emittedContent: String?
            var emittedReasoning: String?
            var isDone = false
            collector.mutate { message in
                if let text = event.textDelta, !text.isEmpty {
                    message.mergeTextDelta(text, now: Date())
                    emittedContent = text
                }
                if let thinking = event.thinkingDelta, !thinking.isEmpty {
                    message.mergeThinkingDelta(thinking, now: Date())
                    emittedReasoning = thinking
                }
                if let toolID = event.toolID {
                    message.beginToolCall(id: toolID, name: event.toolName ?? "")
                }
                if let toolJSON = event.toolInputJSONDelta, !toolJSON.isEmpty {
                    message.appendToolArguments(toolJSON)
                }
                if let stopReason = event.stopReason {
                    message.setStopReason(stopReason)
                }
                if let usage = event.usage {
                    message.mergeUsage(usage)
                }
                if event.done {
                    message.finalize()
                    isDone = true
                }
            }
            if let content = emittedContent {
                await onChunk(LumiStreamChunk(content: content, eventTitle: "生成中"))
            }
            if let reasoning = emittedReasoning {
                await onChunk(LumiStreamChunk(content: reasoning, isThinking: true, eventTitle: "思考中"))
            }
            if isDone {
                await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))
                return false
            }
            return true
        }

        let message = collector.snapshot()
        if message.isError {
            throw AnthropicProviderError.api(message.rawErrorDetail ?? "DeepSeek Anthropic returned an error")
        }
        if message.content.isEmpty && (message.toolCalls?.isEmpty ?? true) {
            throw AnthropicProviderError.invalidResponse("DeepSeek Anthropic returned an empty response")
        }
        return message.toLumiChatMessage()
    }

    func ping(model: String) async throws {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1,
            "messages": [[
                "role": "user",
                "content": [["type": "text", "text": "ping"]],
            ]],
            "stream": false,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await apiService.sendOnce(apiKey: try lumiResolveAPIKey(), body: bodyData)
    }

    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }

    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        if let error = error as? AnthropicProviderError {
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

