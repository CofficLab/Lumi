import Foundation
import HttpKit
import LLMKit
import LumiKernel
import LumiKernel
import LumiKernel

/// 流式请求处理工具函数
///
/// 提供统一的流式请求处理逻辑，各供应商可以使用这些工具函数来实现 `sendStreaming`。
public enum LumiStreamingRequestSupport {
    
    // MARK: - OpenAI Compatible Streaming
    
    /// 执行 OpenAI 兼容的流式请求
    ///
    /// - Parameters:
    ///   - request: LLM 请求
    ///   - adapter: OpenAI 兼容适配器
    ///   - apiService: API 服务
    ///   - baseURLs: 基础 URL 列表（主 URL + 备用 URL）
    ///   - resolveAPIKey: 解析 API Key 的闭包
    ///   - buildRequest: 构建 HTTP 请求的闭包
    ///   - logRawChunk: 记录原始 chunk 的闭包（可选）
    ///   - onChunk: 流式 chunk 回调
    /// - Returns: 聊天消息
    public static func sendOpenAICompatibleStreaming(
        _ request: LumiLLMRequest,
        adapter: OpenAICompatibleProviderAdapter,
        apiService: LLMAPIService,
        baseURLs: [String],
        resolveAPIKey: () throws -> String,
        buildRequest: (URL, String) -> URLRequest,
        logRawChunk: @escaping @Sendable (Data) -> Void = { _ in },
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw LumiLLMProviderSupportError.emptyConversation
        }
        
        try LumiToolNameDeduplication.assertUnique(tools: request.tools)
        
        let body = try adapter.buildStreamingRequestBody(
            messages: LumiLLMRequestMessages.preparedForProvider(request),
            model: request.model,
            tools: request.tools.map(LumiToolSchema.init),
            systemPrompt: ""
        )
        let apiKeyValue = try resolveAPIKey()
        
        var lastError: Error?
        for baseURLString in baseURLs {
            guard let url = URL(string: baseURLString) else {
                if baseURLString == adapter.configuration.baseURL {
                    throw LumiLLMProviderSupportError.invalidBaseURL(baseURLString)
                }
                continue
            }
            
            switch await attemptOpenAIStreamingRequest(
                url: url,
                apiKey: apiKeyValue,
                body: body,
                conversationID: conversationID,
                request: request,
                adapter: adapter,
                apiService: apiService,
                buildRequest: buildRequest,
                logRawChunk: logRawChunk,
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
    
    private static func attemptOpenAIStreamingRequest(
        url: URL,
        apiKey: String,
        body: [String: Any],
        conversationID: UUID,
        request: LumiLLMRequest,
        adapter: OpenAICompatibleProviderAdapter,
        apiService: LLMAPIService,
        buildRequest: (URL, String) -> URLRequest,
        logRawChunk: @escaping @Sendable (Data) -> Void,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async -> StreamingAttemptResult {
        let httpRequest = buildRequest(url, apiKey)
        let state = StreamingState(startTime: CFAbsoluteTimeGetCurrent())
        
        do {
            try await apiService.sendStreamingRequest(
                request: httpRequest,
                body: body,
                onResponseReceived: { response in
                    await state.recordHttpResponse(
                        statusCode: response.statusCode,
                        headers: normalizedHeaders(from: response)
                    )
                },
                onChunk: { chunkData in
                    logRawChunk(chunkData)
                    await processStreamChunk(
                        chunkData: chunkData,
                        parse: { try adapter.parseStreamChunk(data: $0) },
                        state: state,
                        onChunk: onChunk
                    )
                    return true
                }
            )
        } catch is CancellationError {
            return .failure(CancellationError())
        } catch {
            let detail = LumiLLMFailureDetailResolver.resolve(from: error)
            let summary = detail.summary.isEmpty ? (detail.transportDetails ?? error.localizedDescription) : detail.summary
            let detailed = await attachTransportDetails(
                summary: summary,
                request: httpRequest,
                requestBody: body,
                state: nil
            )
            return .retry(LumiLLMProviderSupportError.streamingFailed(detailed))
        }
        
        await state.saveCurrentToolCall()
        if let error = await state.streamError {
            let detailed = await attachTransportDetails(
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
            if await state.stopReason == nil {
                return .retry(LumiLLMProviderSupportError.emptyResponse)
            }
        }
        
        let message = LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: await state.accumulatedContentChunks.joined(),
            providerID: request.model,
            modelName: request.model,
            metadata: await messageMetadata(from: state),
            toolCalls: await state.getFinalToolCalls()?.map {
                LumiToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            reasoningContent: await state.getFinalThinking()
        )
        return .success(message)
    }
    
    // MARK: - Anthropic Compatible Streaming
    
    /// 执行 Anthropic 兼容的流式请求
    ///
    /// - Parameters:
    ///   - request: LLM 请求
    ///   - adapter: Anthropic 兼容适配器
    ///   - apiService: API 服务
    ///   - baseURLs: 基础 URL 列表（主 URL + 备用 URL）
    ///   - resolveAPIKey: 解析 API Key 的闭包
    ///   - buildRequest: 构建 HTTP 请求的闭包
    ///   - systemPrompt: 系统提示词（可选）
    ///   - customizeBody: 自定义请求体的闭包（可选）
    ///   - onChunk: 流式 chunk 回调
    /// - Returns: 聊天消息
    public static func sendAnthropicCompatibleStreaming(
        _ request: LumiLLMRequest,
        adapter: AnthropicCompatibleProviderAdapter,
        apiService: LLMAPIService,
        baseURLs: [String],
        resolveAPIKey: () throws -> String,
        buildRequest: (URL, String) -> URLRequest,
        systemPrompt: String = "",
        customizeBody: ((inout [String: Any], LumiLLMRequest) -> Void)? = nil,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw LumiLLMProviderSupportError.emptyConversation
        }
        
        var body = try adapter.buildStreamingRequestBody(
            messages: LumiLLMRequestMessages.preparedForProvider(request),
            model: request.model,
            tools: request.tools.map(LumiToolSchema.init),
            systemPrompt: systemPrompt
        )
        customizeBody?(&body, request)
        
        let apiKeyValue = try resolveAPIKey()
        
        var lastError: Error?
        for baseURLString in baseURLs {
            guard let url = URL(string: baseURLString) else {
                if baseURLString == adapter.configuration.baseURL {
                    throw LumiLLMProviderSupportError.invalidBaseURL(baseURLString)
                }
                continue
            }
            
            switch await attemptAnthropicStreamingRequest(
                url: url,
                apiKey: apiKeyValue,
                body: body,
                conversationID: conversationID,
                request: request,
                adapter: adapter,
                apiService: apiService,
                buildRequest: buildRequest,
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
    
    private static func attemptAnthropicStreamingRequest(
        url: URL,
        apiKey: String,
        body: [String: Any],
        conversationID: UUID,
        request: LumiLLMRequest,
        adapter: AnthropicCompatibleProviderAdapter,
        apiService: LLMAPIService,
        buildRequest: (URL, String) -> URLRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async -> StreamingAttemptResult {
        let httpRequest = buildRequest(url, apiKey)
        let state = StreamingState(startTime: CFAbsoluteTimeGetCurrent())
        
        do {
            try await apiService.sendStreamingRequest(
                request: httpRequest,
                body: body,
                onResponseReceived: { response in
                    await state.recordHttpResponse(
                        statusCode: response.statusCode,
                        headers: normalizedHeaders(from: response)
                    )
                },
                onChunk: { chunkData in
                    let shouldContinue = await processStreamChunk(
                        chunkData: chunkData,
                        parse: { try adapter.parseStreamChunk(data: $0) },
                        state: state,
                        onChunk: onChunk
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
            let detailed = await attachTransportDetails(
                summary: summary,
                request: httpRequest,
                requestBody: body,
                state: nil
            )
            return .retry(LumiLLMProviderSupportError.streamingFailed(detailed))
        }
        
        await state.saveCurrentToolCall()
        
        if let error = await state.streamError {
            let detailed = await attachTransportDetails(
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
            providerID: request.model,
            modelName: request.model,
            metadata: await messageMetadata(from: state),
            toolCalls: await state.getFinalToolCalls()?.map {
                LumiToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            reasoningContent: await state.getFinalThinking()
        )
        return .success(message)
    }
    
    // MARK: - Helper Types
    
    private enum StreamingAttemptResult {
        case success(LumiChatMessage)
        case retry(Error)
        case failure(Error)
    }
    
    // MARK: - Helper Functions
    
    private static func hasNoDeliveredOutput(_ state: StreamingState) async -> Bool {
        let hasContent = await !state.accumulatedContentChunks.isEmpty
        let hasThinking = await !state.accumulatedThinkingChunks.isEmpty
        let hasToolCalls = await !state.accumulatedToolCalls.isEmpty
        let hasActiveToolCall = await state.currentToolCallId != nil
        return !hasContent && !hasThinking && !hasToolCalls && !hasActiveToolCall
    }
    
    private static func messageMetadata(from state: StreamingState) async -> [String: String] {
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
        
        if let stopReason = await state.stopReason {
            metadata["stopReason"] = stopReason
        }
        
        return metadata
    }
    
    private static func processStreamChunk(
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
    
    private static func attachTransportDetails(
        summary: String,
        request: URLRequest,
        requestBody: [String: Any],
        state: StreamingState?
    ) async -> String {
        let details = await LumiTransportDetailsSupport.transportDetails(
            request: request,
            requestBody: requestBody,
            state: state
        )
        guard !details.isEmpty else { return summary }
        return summary + "\n\n--- Request / Response Details ---\n" + details
    }
    
    private static func normalizedHeaders(from response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let key = key as? String else { continue }
            headers[key] = String(describing: value)
        }
        return headers
    }
}
