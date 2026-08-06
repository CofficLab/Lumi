import Foundation
import LLMKit
import LumiKernel

public final class MiniMaxAnthropicProvider: LumiLLMProvider, @unchecked Sendable {
    public static let shortName = "MiniMax"
    public static let apiKeyHelpURL: String? = MiniMaxOpenAIProvider.apiKeyHelpURL
    public static let info = LumiLLMProviderInfo(
        id: "minimax-tokenplan-anthropic",
        displayName: "MiniMax (Anthropic)",
        description: "MiniMax Token Plan via Anthropic-compatible API",
        defaultModel: "MiniMax-M2.7",
        availableModels: MiniMaxProviderCatalog.models,
        contextWindowSizes: MiniMaxProviderCatalog.contexts,
        modelCapabilities: MiniMaxProviderCatalog.capabilities,
        websiteURL: URL(string: "https://platform.minimaxi.com/")!,
        apiKeyStorageKey: MiniMaxProviderSupport.apiKeyStorageKey
    )
    private let support = MiniMaxProviderSupport()
    private let service: MiniMaxAnthropicService

    public init(baseURL: String = "https://api.minimax.chat/anthropic/v1/messages", network: (any NetworkProviding)? = nil) { service = try! MiniMaxAnthropicService(baseURL: baseURL, network: network) }
    public func lumiResolveAPIKey() throws -> String { try support.resolveAPIKey(displayName: Self.info.displayName) }
    public func hasApiKey() -> Bool { support.hasAPIKey() }
    public func getApiKey() -> String { support.getAPIKey() }
    public func setApiKey(_ apiKey: String) { support.setAPIKey(apiKey) }
    public func removeApiKey() { support.removeAPIKey() }
    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage { try await sendStreaming(request) { _ in } }
    public func sendStreaming(_ request: LumiLLMRequest, onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else { throw MiniMaxProviderError.invalidRequest("Conversation is empty") }
        let body = try JSONSerialization.data(withJSONObject: MiniMaxRequestBuilder.anthropic(request), options: [.sortedKeys])
        let state = MiniMaxMessageState(conversationID: conversationID, providerID: Self.info.id, model: request.model, started: Date())
        try await service.send(apiKey: try lumiResolveAPIKey(), body: body) { event in
            if let error = event.error { state.setError(error); return false }
            state.append(event)
            if let text = event.text, !text.isEmpty { await onChunk(LumiStreamChunk(content: text)) }
            if let thinking = event.thinking, !thinking.isEmpty { await onChunk(LumiStreamChunk(content: thinking, isThinking: true, eventTitle: "思考中")) }
            if event.done { state.finish(); await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束")); return false }
            return true
        }
        let message = state.message()
        if let error = message.rawErrorDetail { throw MiniMaxProviderError.api(statusCode: nil, message: error) }
        if message.content.isEmpty && (message.toolCalls?.isEmpty ?? true) { throw MiniMaxProviderError.invalidResponse("MiniMax returned an empty response") }
        return message
    }

    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult { await AvailabilityService.checkAvailability(provider: self, model: model) }
    public func providerStatus() -> LumiLLMProviderStatus? { LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self) }
    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        if case LumiLLMProviderSupportError.missingAPIKey = error { return .nonRetryable }
        if let status = LumiLLMHTTPErrorParsing.statusCode(from: error), [400, 401, 403].contains(status) { return .nonRetryable }
        return (error as? MiniMaxProviderError)?.llmErrorDisposition ?? (context.attempt < context.maxAttempts ? .retryable() : .nonRetryable)
    }

    public func errorRenderKind(for error: Error) -> String? { support.errorKind(error) }
    public func makeErrorMessage(conversationID: UUID, request: LumiLLMRequest, error: Error, disposition: LumiLLMErrorDisposition) -> LumiChatMessage { support.errorMessage(providerID: Self.info.id, conversationID: conversationID, request: request, error: error, disposition: disposition) }
}
