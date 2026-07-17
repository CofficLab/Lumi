import Foundation
import HttpKit
import LLMKit
import LumiCoreKit

open class AnthropicCompatibleProvider: LumiLLMProvider, @unchecked Sendable {
    open class var info: LumiLLMProviderInfo {
        fatalError("Subclasses must override info")
    }

    private let apiService: LLMAPIService
    private let adapter: AnthropicCompatibleProviderAdapter

    public init(
        configuration: AnthropicCompatibleProviderConfiguration,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        self.apiService = apiService
        self.adapter = AnthropicCompatibleProviderAdapter(configuration: configuration)
    }

    open var lumiAPIService: LLMAPIService { apiService }
    open var lumiAnthropicAdapter: AnthropicCompatibleProviderAdapter { adapter }

    open func hasApiKey() -> Bool {
        LumiAPIKeyTools.has(storageKey: Self.info._apiKeyStorageKey)
    }

    open func getApiKey() -> String {
        LumiAPIKeyTools.get(storageKey: Self.info._apiKeyStorageKey)
    }

    open func setApiKey(_ apiKey: String) {
        LumiAPIKeyTools.set(apiKey, storageKey: Self.info._apiKeyStorageKey)
    }

    open func removeApiKey() {
        LumiAPIKeyTools.remove(storageKey: Self.info._apiKeyStorageKey)
    }

    /// 显式 override 协议扩展默认实现，确保 `Self.info` 通过虚表分发到子类。
    /// 跨模块继承下，协议 witness 表对 `open class var` 的动态分发会回退到基类 fatalError。
    open func lumiResolveAPIKey() throws -> String {
        try LumiAPIKeyTools.resolve(storageKey: Self.info._apiKeyStorageKey, displayName: Self.info.displayName)
    }

    open func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        ErrorDispositionResolver.disposition(for: error, context: context)
    }

    open func errorRenderKind(for error: Error) -> String? {
        nil
    }

    open func makeErrorMessage(
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

    open func buildRequest(url: URL, apiKey: String) -> URLRequest {
        adapter.buildRequest(url: url, apiKey: apiKey)
    }

    open func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    /// 默认实现：发送最小 ping 请求检测连接。子类应 override 以提供带缓存和结构化错误报告的版本。
    open func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        let request = LumiLLMRequest(
            messages: [LumiChatMessage(conversationID: UUID(), role: .user, content: "ping")],
            model: model
        )
        do {
            _ = try await send(request)
            return .available
        } catch {
            return .unavailable(LumiLLMFailureDetailResolver.resolve(from: error))
        }
    }

    /// 默认实现：返回 nil 表示无异常状态。子类应 override 以提供 API Key 缺失等状态信息。
    open func providerStatus() -> LumiLLMProviderStatus? {
        nil
    }

    open func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw LumiLLMProviderSupportError.emptyConversation
        }

        let body = try buildAnthropicStreamingRequestBody(for: request)
        let apiKeyValue = try lumiResolveAPIKey()

        var lastError: Error?
        for baseURLString in resolvedBaseURLs() {
            guard let url = URL(string: baseURLString) else {
                if baseURLString == adapter.configuration.baseURL {
                    throw LumiLLMProviderSupportError.invalidBaseURL(baseURLString)
                }
                continue
            }

            switch await attemptStreamingRequest(
                url: url,
                apiKey: apiKeyValue,
                body: body,
                conversationID: conversationID,
                request: request,
                onChunk: onChunk
            ) {
            case let .success(message):
                return message
            case let .retry(error):
                lastError = error
            case let .failure(error):
                throw error
            }
        }

        if let lastError {
            throw lastError
        }
        throw LumiLLMProviderSupportError.allEndpointsFailed
    }

    /// 子类可覆盖以注入 Claude Code 等网关所需的 system / metadata / betas。
    open func anthropicStreamingSystemPrompt(for request: LumiLLMRequest) -> String {
        ""
    }

    open func customizeAnthropicStreamingBody(
        _ body: inout [String: Any],
        request: LumiLLMRequest
    ) {}

    private func buildAnthropicStreamingRequestBody(for request: LumiLLMRequest) throws -> [String: Any] {
        var body = try adapter.buildStreamingRequestBody(
            messages: LumiLLMRequestMessages.preparedForProvider(request),
            model: request.model,
            tools: request.tools.map(LumiToolSchema.init),
            systemPrompt: anthropicStreamingSystemPrompt(for: request)
        )
        customizeAnthropicStreamingBody(&body, request: request)
        return body
    }

    private func resolvedBaseURLs() -> [String] {
        [adapter.configuration.baseURL] + adapter.configuration.fallbackBaseURLs
    }

    private enum StreamingAttemptResult {
        case success(LumiChatMessage)
        case retry(Error)
        case failure(Error)
    }

    private func attemptStreamingRequest(
        url: URL,
        apiKey: String,
        body: [String: Any],
        conversationID: UUID,
        request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async -> StreamingAttemptResult {
        let httpRequest = buildRequest(url: url, apiKey: apiKey)
        let state = StreamingState(startTime: CFAbsoluteTimeGetCurrent())
        let chunkHandler = onChunk

        do {
            try await apiService.sendStreamingRequest(
                request: httpRequest,
                body: body,
                onResponseReceived: { response in
                    await state.recordHttpResponse(
                        statusCode: response.statusCode,
                        headers: OpenAICompatibleLumiProvider.normalizedHeaders(from: response)
                    )
                },
                onChunk: { [self] chunkData in
                    let shouldContinue = await OpenAICompatibleLumiProvider.processStreamChunk(
                        chunkData: chunkData,
                        parse: { try self.adapter.parseStreamChunk(data: $0) },
                        state: state,
                        onChunk: chunkHandler
                    )
                    if !shouldContinue {
                        return false
                    }
                    if await state.streamError != nil,
                       await state.httpResponseBody == nil {
                        await state.recordHttpResponse(
                            statusCode: await state.httpStatusCode,
                            headers: nil,
                            body: String(data: chunkData, encoding: .utf8)
                        )
                    }
                    return true
                }
            )
        } catch is CancellationError {
            return .failure(CancellationError())
        } catch {
            let detail = LumiLLMFailureDetailResolver.resolve(from: error)
            let summary = detail.summary.isEmpty ? (detail.transportDetails ?? error.localizedDescription) : detail.summary
            let detailed = await OpenAICompatibleLumiProvider.attachTransportDetails(
                summary: summary,
                request: httpRequest,
                requestBody: body,
                state: nil
            )
            return .retry(LumiLLMProviderSupportError.streamingFailed(detailed))
        }

        await state.saveCurrentToolCall()

        if let error = await state.streamError {
            let detailed = await OpenAICompatibleLumiProvider.attachTransportDetails(
                summary: error,
                request: httpRequest,
                requestBody: body,
                state: state
            )
            let streamError = LumiLLMProviderSupportError.streamingFailed(detailed)
            if await hasNoDeliveredOutput(state) {
                return .retry(streamError)
            }
            return .failure(streamError)
        }

        let message = LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: await state.accumulatedContentChunks.joined(),
            providerID: Self.info.id,
            modelName: request.model,
            metadata: await OpenAICompatibleLumiProvider.messageMetadata(from: state),
            toolCalls: await state.getFinalToolCalls()?.map {
                LumiToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            }
        )
        return .success(message)
    }

    private func hasNoDeliveredOutput(_ state: StreamingState) async -> Bool {
        let hasContent = await !state.accumulatedContentChunks.isEmpty
        let hasThinking = await !state.accumulatedThinkingChunks.isEmpty
        let hasToolCalls = await !state.accumulatedToolCalls.isEmpty
        let hasActiveToolCall = await state.currentToolCallId != nil
        return !hasContent && !hasThinking && !hasToolCalls && !hasActiveToolCall
    }
}
