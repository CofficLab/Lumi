import Foundation
import KeychainKit
import LumiKernel

public final class DeepSeekProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "deepseek",
        displayName: LumiPluginLocalization.string("DeepSeek", bundle: .module),
        description: LumiPluginLocalization.string("DeepSeek AI", bundle: .module),
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
        apiKeyStorageKey: "DevAssistant_ApiKey_DeepSeek"
    )

    private let apiService: DeepSeekAPIService

    public init(
        baseURL: String = "https://api.deepseek.com/v1/chat/completions",
        network: (any NetworkProviding)? = nil
    ) {
        self.apiService = DeepSeekAPIService(baseURL: baseURL, network: network)
    }

    // MARK: - LumiLLMProvider Protocol

    public func lumiResolveAPIKey() throws -> String {
        guard let key = Self.info._apiKeyStorageKey else {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        guard let value = KeychainStore.shared.loadMigratingLegacyUserDefaults(forKey: key), !value.isEmpty else {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return value
    }

    public func hasApiKey() -> Bool {
        guard let key = Self.info._apiKeyStorageKey else { return false }
        return !(KeychainStore.shared.loadMigratingLegacyUserDefaults(forKey: key) ?? "").isEmpty
    }

    public func getApiKey() -> String {
        guard let key = Self.info._apiKeyStorageKey else { return "" }
        return KeychainStore.shared.loadMigratingLegacyUserDefaults(forKey: key) ?? ""
    }

    public func setApiKey(_ apiKey: String) {
        guard let key = Self.info._apiKeyStorageKey else { return }
        KeychainStore.shared.set(apiKey, forKey: key)
    }

    public func removeApiKey() {
        guard let key = Self.info._apiKeyStorageKey else { return }
        KeychainStore.shared.remove(forKey: key)
    }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw DeepSeekProviderError.invalidRequest("Conversation is empty")
        }
        let body = DeepSeekRequestBuilder.body(for: request)
        guard let url = URL(string: apiService.baseURL) else {
            throw DeepSeekProviderError.invalidRequest("Invalid DeepSeek URL")
        }
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(try lumiResolveAPIKey())", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let state = DeepSeekStreamState()
        try await apiService.send(request: httpRequest, body: body) { event in
            if let error = event.error {
                await state.setError(error)
                return false
            }
            await state.append(event)
            if let content = event.content, !content.isEmpty {
                await onChunk(LumiStreamChunk(content: content, eventTitle: "生成中"))
            }
            if let reasoning = event.reasoning, !reasoning.isEmpty {
                await onChunk(LumiStreamChunk(content: reasoning, isThinking: true, eventTitle: "思考中"))
            }
            if event.done {
                await state.saveTool()
                await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))
                return false
            }
            return true
        }

        if let error = await state.error { throw DeepSeekProviderError.api(error) }
        await state.saveTool()
        let toolCalls = await state.toolCalls
        let content = await state.content
        guard !content.isEmpty || !toolCalls.isEmpty else {
            throw DeepSeekProviderError.invalidResponse("DeepSeek returned an empty response")
        }
        let metadata = MessageTokenMetadata.metadata(
            inputTokens: await state.inputTokens,
            outputTokens: await state.outputTokens,
            cachedInputTokens: await state.cacheHitTokens,
            cacheTotalInputTokens: await state.cacheTotalInputTokens
        )
        var finalMetadata = metadata
        if let stopReason = await state.stopReason { finalMetadata["stopReason"] = stopReason }
        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: content,
            providerID: Self.info.id,
            modelName: request.model,
            metadata: finalMetadata,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            reasoningContent: (await state.reasoning).isEmpty ? nil : await state.reasoning
        )
    }

    func ping(model: String) async throws {
        guard let url = URL(string: apiService.baseURL) else {
            throw DeepSeekProviderError.invalidRequest("Invalid DeepSeek URL")
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
        if let error = error as? DeepSeekProviderError {
            return error.llmErrorDisposition
        }
        return context.attempt < context.maxAttempts
            ? .retryable()
            : .nonRetryable
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
        var metadata = disposition.metadataEntries
        if let error = error as? DeepSeekProviderError, let status = error.statusCode {
            metadata["httpStatusCode"] = String(status)
        }
        return LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: error.localizedDescription,
            isError: true,
            rawErrorDetail: error.localizedDescription,
            metadata: metadata
        )
    }
}
