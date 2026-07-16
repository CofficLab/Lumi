import Foundation
import HttpKit
import LLMKit
import LumiCoreKit

public typealias LumiOpenAICompatibleProviderConfiguration = OpenAICompatibleProviderConfiguration
public typealias LumiAnthropicCompatibleProviderConfiguration = AnthropicCompatibleProviderConfiguration

private enum LumiLLMRequestMessages {
    static func preparedForProvider(_ request: LumiLLMRequest) -> [LLMKit.ChatMessage] {
        LumiVisionMessageSupport.preparedMessages(for: request)
    }
}

open class OpenAICompatibleLumiProvider: LumiLLMProvider, @unchecked Sendable {
    open class var info: LumiLLMProviderInfo {
        fatalError("Subclasses must override info")
    }

    private let apiService: LLMAPIService
    private let adapter: OpenAICompatibleProviderAdapter

    public init(
        configuration: OpenAICompatibleProviderConfiguration,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        self.apiService = apiService
        self.adapter = OpenAICompatibleProviderAdapter(configuration: configuration)
    }

    open var lumiAPIService: LLMAPIService { apiService }
    open var lumiOpenAIAdapter: OpenAICompatibleProviderAdapter { adapter }

    /// 显式 override 协议扩展默认实现，确保 `Self.info` 通过虚表分发到子类。
    /// 跨模块继承下，协议 witness 表对 `open class var` 的动态分发会回退到基类 fatalError。
    open func lumiResolveAPIKey() throws -> String {
        if Self.info.isLocal { return "" }
        guard let storageKey = Self.info._apiKeyStorageKey else {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        let key = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
        if key.isEmpty {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return key
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

    open func logRawStreamChunk(_ data: Data) {
        // 子类可覆写以记录原始流式 chunk
    }

    open func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw LumiLLMProviderSupportError.emptyConversation
        }

        // 检测重复的工具名，避免供应商返回 "Tool names must be unique." 错误。
        // 重复时抛出 LumiToolRegistrationError，由聊天发送流程捕获并以错误消息呈现。
        try LumiToolNameDeduplication.assertUnique(tools: request.tools)

        let body = try adapter.buildStreamingRequestBody(
            messages: LumiLLMRequestMessages.preparedForProvider(request),
            model: request.model,
            tools: request.tools.map(LumiToolSchema.init),
            systemPrompt: ""
        )
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
            case .success(let message):
                return message
            case .retry(let error):
                lastError = error
            case .failure(let error):
                throw error
            }
        }

        if let lastError {
            throw lastError
        }
        throw LumiLLMProviderSupportError.allEndpointsFailed
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
                        headers: Self.normalizedHeaders(from: response)
                    )
                },
                onChunk: { [self] chunkData in
                    logRawStreamChunk(chunkData)
                    await Self.processStreamChunk(
                        chunkData: chunkData,
                        parse: { try self.adapter.parseStreamChunk(data: $0) },
                        state: state,
                        onChunk: chunkHandler
                    )
                    return true
                }
            )
        } catch is CancellationError {
            return .failure(CancellationError())
        } catch {
            let detail = LumiLLMFailureDetailResolver.resolve(from: error)
            let summary = detail.summary.isEmpty ? (detail.transportDetails ?? error.localizedDescription) : detail.summary
            let detailed = await Self.attachTransportDetails(
                summary: summary,
                request: httpRequest,
                requestBody: body,
                state: nil
            )
            return .retry(LumiLLMProviderSupportError.streamingFailed(detailed))
        }

        await state.saveCurrentToolCall()
        if let error = await state.streamError {
            let detailed = await Self.attachTransportDetails(
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

        if await hasNoDeliveredOutput(state) {
            // 如果有 stopReason 说明模型正常结束（如结构化输出两轮协议的第 2 轮），是合法空响应
            if await state.stopReason == nil {
                return .retry(LumiLLMProviderSupportError.emptyResponse)
            }
            // 合法空响应：直接返回空消息，不重试
        }

        let message = LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: await state.accumulatedContentChunks.joined(),
            providerID: Self.info.id,
            modelName: request.model,
            metadata: await Self.messageMetadata(from: state),
            toolCalls: await state.getFinalToolCalls()?.map {
                LumiToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            reasoningContent: await state.getFinalThinking()
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

    fileprivate static func messageMetadata(from state: StreamingState) async -> [String: String] {
        let endTime = CFAbsoluteTimeGetCurrent()
        let startTime = await state.startTime
        var metadata = LumiMessageTokenMetadata.metadata(
            inputTokens: await state.inputTokens,
            outputTokens: await state.outputTokens
        )
        metadata.merge(
            LumiMessagePerformanceMetadata.metadata(
                latencyMs: (endTime - startTime) * 1000.0,
                timeToFirstTokenMs: await state.timeToFirstToken,
                streamingDurationMs: await state.getStreamingDuration()
            )
        ) { _, new in new }

        // 持久化 stopReason，供 Turn 层和诊断工具使用
        if let stopReason = await state.stopReason {
            metadata["stopReason"] = stopReason
        }

        return metadata
    }

    fileprivate static func attachTransportDetails(
        summary: String,
        request: URLRequest,
        requestBody: [String: Any],
        state: StreamingState?
    ) async -> String {
        let details = await transportDetails(request: request, requestBody: requestBody, state: state)
        guard !details.isEmpty else { return summary }
        return summary + "\n\n--- Request / Response Details ---\n" + details
    }

    fileprivate static func transportDetails(
        request: URLRequest,
        requestBody: [String: Any],
        state: StreamingState?
    ) async -> String {
        var lines: [String] = []
        lines.append("Request URL: \(request.url?.absoluteString ?? "-")")
        lines.append("Request Method: \(request.httpMethod ?? "POST")")
        lines.append("Request Headers:")
        lines.append(prettyHeaders(maskedHeaders(request.allHTTPHeaderFields ?? [:])))
        lines.append("Request Body:")
        lines.append(LumiLLMTransportDetails.truncatedBodyForDisplay(prettyJSON(requestBody)))

        if let state {
            let status = await state.httpStatusCode
            let responseHeaders = await state.httpResponseHeaders ?? [:]
            let responseBody = await state.httpResponseBody ?? "-"
            lines.append("Response Status: \(status.map(String.init) ?? "-")")
            lines.append("Response Headers:")
            lines.append(prettyHeaders(maskedHeaders(responseHeaders)))
            lines.append("Response Body:")
            lines.append(LumiLLMTransportDetails.truncatedBodyForDisplay(responseBody))
        }
        return lines.joined(separator: "\n")
    }

    fileprivate static func normalizedHeaders(from response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let key = key as? String else { continue }
            headers[key] = String(describing: value)
        }
        return headers
    }

    fileprivate static func maskedHeaders(_ headers: [String: String]) -> [String: String] {
        var masked = headers
        for (key, value) in headers {
            let lower = key.lowercased()
            if lower == "authorization" || lower == "x-api-key" || lower.contains("token") || lower.contains("api-key") {
                masked[key] = maskSecret(value)
            }
        }
        return masked
    }

    fileprivate static func maskSecret(_ value: String) -> String {
        guard value.count > 8 else { return "***" }
        let prefix = value.prefix(4)
        let suffix = value.suffix(4)
        return "\(prefix)***\(suffix)"
    }

    fileprivate static func prettyHeaders(_ headers: [String: String]) -> String {
        guard !headers.isEmpty else { return "-" }
        return headers.keys.sorted().map { "\($0): \(headers[$0] ?? "")" }.joined(separator: "\n")
    }

    fileprivate static func prettyJSON(_ body: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "-"
        }
        return text
    }

    fileprivate static func processStreamChunk(
        chunkData: Data,
        parse: (Data) throws -> StreamChunk?,
        state: StreamingState,
        onChunk: @Sendable (LumiStreamChunk) async -> Void
    ) async -> Bool {
        do {
            try Task.checkCancellation()
            guard let parsed = try parse(chunkData) else {
                return true
            }

            if let content = parsed.content, parsed.eventType == .textDelta {
                await state.recordFirstToken()
                await state.appendContent(content)
                await onChunk(LumiStreamChunk(content: content, eventTitle: "生成中"))
            }

            if let content = parsed.content, parsed.eventType == .thinkingDelta {
                await state.appendThinking(content)
                await onChunk(LumiStreamChunk(content: content, isThinking: true, eventTitle: "思考中"))
            }

            if let toolCalls = parsed.toolCalls {
                await state.saveCurrentToolCall()
                if let firstToolCall = toolCalls.first {
                    await state.startNewToolCall(
                        id: firstToolCall.id,
                        name: firstToolCall.name,
                        hasPartialJson: parsed.partialJson != nil,
                        arguments: firstToolCall.arguments
                    )
                }
            }

            if let partialJson = parsed.partialJson {
                await state.appendToolCallArguments(partialJson)
            }

            if let error = parsed.error {
                await state.setError(error)
            }

            if parsed.inputTokens != nil || parsed.outputTokens != nil {
                await state.updateTokens(input: parsed.inputTokens, output: parsed.outputTokens)
            }

            if parsed.isDone {
                await state.saveCurrentToolCall()
                await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))
                return false
            }

            if let stopReason = parsed.stopReason {
                await state.setStopReason(stopReason)
            }

            return true
        } catch is CancellationError {
            return false
        } catch {
            return true
        }
    }
}

open class AnthropicCompatibleLumiProvider: LumiLLMProvider, @unchecked Sendable {
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

    /// 显式 override 协议扩展默认实现，确保 `Self.info` 通过虚表分发到子类。
    /// 跨模块继承下，协议 witness 表对 `open class var` 的动态分发会回退到基类 fatalError。
    open func lumiResolveAPIKey() throws -> String {
        if Self.info.isLocal { return "" }
        guard let storageKey = Self.info._apiKeyStorageKey else {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        let key = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
        if key.isEmpty {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return key
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
            case .success(let message):
                return message
            case .retry(let error):
                lastError = error
            case .failure(let error):
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

// `LumiLLMProviderSupportError` 已迁移到 `LumiCoreKit`（`LumiLLMProvider` 协议
// 默认实现需要直接抛该错误），由 `LumiLLMProviderSupport` 透传使用。

private struct LumiToolSchema: LLMToolSchemaProviding {
    let name: String
    let toolDescription: String
    let inputSchema: [String: Any]

    init(_ tool: any LumiAgentTool) {
        self.name = tool.name
        self.toolDescription = tool.toolDescription
        self.inputSchema = tool.inputSchema.anyValue as? [String: Any] ?? [:]
    }
}
