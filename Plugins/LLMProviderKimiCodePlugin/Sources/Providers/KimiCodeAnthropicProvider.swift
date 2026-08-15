import Foundation
import LLMKit
import KernelLumi

public final class KimiCodeAnthropicProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "kimi-code-anthropic",
        displayName: LumiPluginLocalization.string("Kimi Code (Anthropic)", bundle: .module),
        description: LumiPluginLocalization.string("Kimi Code API via Anthropic-compatible endpoint.", bundle: .module),
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
        apiFormat: .anthropic,
        apiKeyStorageKey: KimiCodePlugin.apiKeyStorageKey
    )

    private let apiService: KimiCodeAnthropicService

    public init(
        baseURL: String = "https://api.kimi.com/coding/v1",
        network: (any NetworkProviding)? = nil
    ) {
        self.apiService = KimiCodeAnthropicService(baseURL: baseURL, network: network)
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
            throw KimiCodeAnthropicProviderError.invalidRequest("Conversation is empty")
        }

        let body = AnthropicKimiCodeRequestBuilder.body(for: request)
        let toolNameMap = AnthropicKimiCodeRequestBuilder.toolNameMap(for: request)
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let apiKey = try lumiResolveAPIKey()

        let requestStartedAt = Date()
        let collector = KimiCodeChatMessageCollector(
            message: KimiCodeChatMessage.assembling(
                conversationID: conversationID,
                providerID: Self.info.id,
                modelName: request.model,
                requestStartedAt: requestStartedAt
            )
        )

        try await apiService.send(apiKey: apiKey, body: bodyData) { event in
            if let error = event.error {
                collector.mutate { $0.isError = true; $0.rawErrorDetail = error }
                return false
            }

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
                if let signature = event.thinkingSignature, !signature.isEmpty {
                    message.thinkingSignature = signature
                }
                if let toolID = event.toolID {
                    let rawName = event.toolName ?? ""
                    message.beginToolCall(id: toolID, name: toolNameMap[rawName] ?? rawName)
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
            throw KimiCodeAnthropicProviderError.api(message.rawErrorDetail ?? "Kimi Code Anthropic returned an error")
        }
        if message.hitMaxTokensWithoutOutput {
            throw KimiCodeAnthropicProviderError.maxTokensExceeded(message.outputTokenCount)
        }
        if message.content.isEmpty && (message.toolCalls?.isEmpty ?? true) {
            throw KimiCodeAnthropicProviderError.invalidResponse("Kimi Code Anthropic returned an empty response")
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
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        _ = try await apiService.sendOnce(apiKey: try lumiResolveAPIKey(), body: bodyData)
    }

    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }

    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        if let error = error as? KimiCodeAnthropicProviderError {
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