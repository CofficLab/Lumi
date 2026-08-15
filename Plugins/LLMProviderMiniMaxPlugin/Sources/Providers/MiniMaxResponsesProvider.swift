import Foundation
import LLMKit
import KernelLumi

private func emitResponsesTextSegments(
    _ event: MiniMaxResponsesEvent,
    onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
) async {
    if let text = event.text, !text.isEmpty {
        await onChunk(LumiStreamChunk(content: text))
    }
    if let reasoning = event.reasoning, !reasoning.isEmpty {
        await onChunk(LumiStreamChunk(content: reasoning, isThinking: true, eventTitle: "思考中"))
    }
}

public final class MiniMaxResponsesProvider: LumiLLMProvider, @unchecked Sendable {
    public static let shortName = "MiniMax"
    public static let apiKeyHelpURL: String? = "https://platform.minimaxi.com/user-center/basic-information/Interface-key"
    public static let info = LumiLLMProviderInfo(
        id: "minimax-responses",
        displayName: "MiniMax (Responses)",
        description: "MiniMax via OpenAI Responses API (supports reasoning effort control)",
        defaultModel: "MiniMax-M3",
        availableModels: [
            LumiModelInfo(id: "MiniMax-M3", contextWindowSize: 1_000_000, capabilities: .init(supportsVision: true, supportsTools: true, thinkingAndReasoning: .threeLevel)),
            LumiModelInfo(id: "MiniMax-M2.7", contextWindowSize: 204_800, capabilities: .init(supportsVision: true, supportsTools: true)),
            LumiModelInfo(id: "MiniMax-M2.7-highspeed", contextWindowSize: 204_800, capabilities: .init(supportsVision: true, supportsTools: true)),
            LumiModelInfo(id: "MiniMax-M2.5", contextWindowSize: 204_800, capabilities: .init(supportsVision: false, supportsTools: true)),
            LumiModelInfo(id: "MiniMax-M2.5-highspeed", contextWindowSize: 204_800, capabilities: .init(supportsVision: false, supportsTools: true)),
            LumiModelInfo(id: "MiniMax-M2.1", contextWindowSize: 204_800, capabilities: .init(supportsVision: false, supportsTools: true)),
            LumiModelInfo(id: "MiniMax-M2.1-highspeed", contextWindowSize: 204_800, capabilities: .init(supportsVision: false, supportsTools: true)),
            LumiModelInfo(id: "MiniMax-M2", contextWindowSize: 204_800, capabilities: .init(supportsVision: false, supportsTools: true)),
            LumiModelInfo(id: "MiniMax-Text-01", contextWindowSize: 4_000_000, capabilities: .init(supportsVision: false, supportsTools: false)),
        ],
        websiteURL: URL(string: "https://platform.minimaxi.com/")!,
        apiFormat: .responses,
        apiKeyStorageKey: MiniMaxProviderSupport.apiKeyStorageKey
    )
    private let support = MiniMaxProviderSupport()
    private let service: MiniMaxResponsesService

    public init(baseURL: String = "https://api.minimaxi.com/v1/responses", network: (any NetworkProviding)? = nil) {
        service = try! MiniMaxResponsesService(baseURL: baseURL, network: network)
    }

    public func lumiResolveAPIKey() throws -> String {
        try support.resolveAPIKey(displayName: Self.info.displayName)
    }

    public func hasApiKey() -> Bool {
        support.hasAPIKey()
    }

    public func getApiKey() -> String {
        support.getAPIKey()
    }

    public func setApiKey(_ apiKey: String) {
        support.setAPIKey(apiKey)
    }

    public func removeApiKey() {
        support.removeAPIKey()
    }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw MiniMaxProviderError.invalidRequest("Conversation is empty")
        }

        let body = try JSONEncoder().encode(MiniMaxResponsesBuilder.build(request))
        let state = MiniMaxResponsesMessageState(
            conversationID: conversationID,
            providerID: Self.info.id,
            model: request.model,
            started: Date(),
            toolNameMap: MiniMaxRequestBuilder.toolNameMap(for: request)
        )

        try await service.send(apiKey: try lumiResolveAPIKey(), body: body) { [weak self] event in
            if let error = event.error {
                state.setError(error)
                await emitResponsesTextSegments(event, onChunk: onChunk)
                if event.isDone { state.finish() }
                return false
            }

            state.append(event)
            await emitResponsesTextSegments(event, onChunk: onChunk)

            if event.isDone {
                state.finish()
                await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))
                return false
            }
            return true
        }

        let message = state.message()
        if let error = message.rawErrorDetail {
            throw MiniMaxProviderError.api(statusCode: nil, message: error)
        }
        if message.content.isEmpty && (message.toolCalls?.isEmpty ?? true) {
            throw MiniMaxProviderError.invalidResponse("MiniMax returned an empty response")
        }
        return message
    }

    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }

    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return .nonRetryable
        }
        if let status = LumiLLMHTTPErrorParsing.statusCode(from: error), [400, 401, 403].contains(status) {
            return .nonRetryable
        }
        return (error as? MiniMaxProviderError)?.llmErrorDisposition
            ?? (context.attempt < context.maxAttempts ? .retryable() : .nonRetryable)
    }

    public func errorRenderKind(for error: Error) -> String? {
        support.errorKind(error)
    }

    public func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        support.errorMessage(providerID: Self.info.id, conversationID: conversationID, request: request, error: error, disposition: disposition)
    }
}
