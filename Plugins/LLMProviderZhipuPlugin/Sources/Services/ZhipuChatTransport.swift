import AgentToolKit
import Foundation
import HttpKit
import LLMKit
import LLMProviderKit
import LumiCoreKit

/// 智谱聊天 HTTP/SSE 传输：凭证校验、请求构建、流式聚合与错误映射。
enum ZhipuChatTransport {
    private static let defaultHTTPClient = HTTPClient()

    /// 测试时可替换为带 Mock URLProtocol 的 client。
    nonisolated(unsafe) internal static var httpClient: HTTPClient = defaultHTTPClient

    static func streamChat(
        provider: ZhipuProvider,
        messages: [LumiCoreKit.ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        maxThinkingLength: Int,
        onChunk: @escaping @Sendable (LumiCoreKit.StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> LumiCoreKit.ChatMessage {
        try config.validate()
        try ZhipuProvider.validateCredentials()

        let startTime = CFAbsoluteTimeGetCurrent()
        let conversationId = messages.first?.conversationId ?? UUID()

        guard let url = URL(string: provider.baseURL) else {
            throw LLMServiceError.invalidBaseURL(provider.baseURL)
        }

        let prepared = provider.prepareMessagesForProvider(messages)
        var body = try provider.buildStreamingRequestBody(
            messages: prepared,
            model: config.model,
            tools: tools,
            systemPrompt: ""
        )
        provider.applyGenerationOptions(config: config, model: config.model, to: &body)

        let request = provider.buildRequest(url: url)
        ZhipuRequestDebugLog.logOutgoingRequest(
            mode: "stream",
            config: config,
            rawMessages: messages,
            preparedMessages: prepared,
            request: request,
            body: body,
            tools: tools
        )
        debugPrint(
            "[ZhipuTransport] stream model=\(config.model) tools=\((body["tools"] as? [[String: Any]])?.count ?? 0) "
                + "bodyBytes=\((try? JSONSerialization.data(withJSONObject: body))?.count ?? -1)"
        )
        let state = StreamingState(startTime: startTime, maxThinkingLength: maxThinkingLength)

        do {
            try await httpClient.sendStreamingJSONRequest(
                request: request,
                body: body,
                onRequestStart: onRequestStart
            ) { chunkData in
                do {
                    try Task.checkCancellation()

                    guard let parsed = try provider.parseStreamChunk(data: chunkData) else {
                        return true
                    }

                    let rawPayload = String(data: chunkData, encoding: .utf8)
                    let chunk = parsed.withRawStreamPayload(rawPayload)
                    await consume(chunk: chunk, state: state)
                    await onChunk(chunk)
                    return !chunk.isDone
                } catch {
                    return true
                }
            }
        } catch is CancellationError {
            throw LLMServiceError.cancelled
        } catch let error as HTTPClientError {
            throw mapHTTPClientError(error, provider: provider)
        }

        await state.saveCurrentToolCall()

        if let error = await state.streamError {
            throw LLMServiceError.requestFailed(error)
        }

        let finalContent = await state.accumulatedContentChunks.joined()
        let finalThinking = await state.getFinalThinking()
        let kitToolCalls = await state.getFinalToolCalls()

        if finalContent.isEmpty, finalThinking == nil, kitToolCalls == nil {
            throw LLMServiceError.requestFailed("模型流式响应为空，请检查供应商返回内容、max_tokens 设置或请求日志")
        }

        return LumiCoreKit.ChatMessage(
            role: .assistant,
            conversationId: conversationId,
            content: finalContent,
            toolCalls: kitToolCalls?.map { ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
            providerId: config.providerId,
            modelName: config.model,
            latency: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0,
            inputTokens: await state.inputTokens,
            outputTokens: await state.outputTokens,
            totalTokens: await state.totalTokens,
            timeToFirstToken: await state.timeToFirstToken,
            streamingDuration: await state.getStreamingDuration(),
            finishReason: await state.stopReason,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            thinkingContent: finalThinking
        )
    }

    static func sendMessage(
        provider: ZhipuProvider,
        messages: [LumiCoreKit.ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
    ) async throws -> LumiCoreKit.ChatMessage {
        try config.validate()
        try ZhipuProvider.validateCredentials()

        let startTime = CFAbsoluteTimeGetCurrent()
        let conversationId = messages.first?.conversationId ?? UUID()

        guard let url = URL(string: provider.baseURL) else {
            throw LLMServiceError.invalidBaseURL(provider.baseURL)
        }

        let prepared = provider.prepareMessagesForProvider(messages)
        var body = try provider.buildRequestBody(
            messages: prepared,
            model: config.model,
            tools: tools,
            systemPrompt: ""
        )
        provider.applyGenerationOptions(config: config, model: config.model, to: &body)

        let request = provider.buildRequest(url: url)
        ZhipuRequestDebugLog.logOutgoingRequest(
            mode: "send",
            config: config,
            rawMessages: messages,
            preparedMessages: prepared,
            request: request,
            body: body,
            tools: tools
        )

        let data: Data
        do {
            data = try await httpClient.sendJSONRequest(request: request, body: body)
        } catch is CancellationError {
            throw LLMServiceError.cancelled
        } catch let error as HTTPClientError {
            throw mapHTTPClientError(error, provider: provider)
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }

        let response = try provider.parseResponse(data: data)
        if response.content.isEmpty, response.toolCalls?.isEmpty != false {
            throw LLMServiceError.requestFailed("模型响应为空，请检查供应商返回内容、max_tokens 设置或请求日志")
        }

        return LumiCoreKit.ChatMessage(
            role: .assistant,
            conversationId: conversationId,
            content: response.content,
            toolCalls: response.toolCalls,
            providerId: config.providerId,
            modelName: config.model,
            latency: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0,
            temperature: config.temperature,
            maxTokens: config.maxTokens
        )
    }

    private static func consume(chunk: LumiCoreKit.StreamChunk, state: StreamingState) async {
        if let content = chunk.content, chunk.eventType == .textDelta {
            await state.recordFirstToken()
            await state.appendContent(content)
        }

        if let content = chunk.content, chunk.eventType == .thinkingDelta {
            await state.appendThinking(content)
        }

        if let toolCalls = chunk.toolCalls {
            await state.saveCurrentToolCall()
            if let firstToolCall = toolCalls.first {
                await state.startNewToolCall(
                    id: firstToolCall.id,
                    name: firstToolCall.name,
                    hasPartialJson: chunk.partialJson != nil,
                    arguments: firstToolCall.arguments
                )
            }
        }

        if let partialJson = chunk.partialJson {
            await state.appendToolCallArguments(partialJson)
        }

        if let error = chunk.error {
            await state.setError(error)
        }

        await state.updateTokens(input: chunk.inputTokens, output: chunk.outputTokens)
        if let reason = chunk.stopReason {
            await state.setStopReason(reason)
        }

        if chunk.isDone {
            await state.saveCurrentToolCall()
        }
    }

    private static func mapHTTPClientError(
        _ error: HTTPClientError,
        provider: ZhipuProvider
    ) -> LLMServiceError {
        switch error {
        case let .httpError(statusCode, message):
            ZhipuRequestDebugLog.logHTTPError(statusCode: statusCode, responseBody: message)
            debugPrint("[ZhipuTransport] HTTP \(statusCode): \(message.prefix(300))")
            let data = message.data(using: .utf8)
            if let parsed = provider.parseProviderHTTPError(data: data, statusCode: statusCode) {
                return LLMServiceError.requestFailed(
                    "[HTTP \(statusCode)] \(parsed.message)",
                    statusCode: statusCode
                )
            }
            return LLMServiceError.requestFailed("[HTTP \(statusCode)] \(message)", statusCode: statusCode)
        case let .requestFailed(underlying):
            return LLMServiceError.requestFailed(underlying.localizedDescription)
        default:
            return LLMServiceError.requestFailed(error.localizedDescription)
        }
    }
}
